from __future__ import annotations

import random
import time
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image

from app.core.config import Settings
from app.db.repository import DataRepository

try:
    from ultralytics import YOLO
except Exception:  # pragma: no cover
    YOLO = None


class DamageDetectionService:
    def __init__(self, settings: Settings, repository: DataRepository):
        self.settings = settings
        self.repository = repository
        self.model = None
        self.model_name = "demo-mock-detector"
        self._load_model()

    def _load_model(self):
        if YOLO is None:
            return
        model_path = Path(self.settings.yolo_model_path)
        if model_path.exists():
            self.model = YOLO(str(model_path))
            self.model_name = f"yolo:{model_path.name}"

    def detect(
        self,
        image_path: str,
        image_id: str,
        road_id: str | None = None,
    ) -> dict[str, Any]:
        start = time.perf_counter()
        path_obj = Path(image_path)
        image_width, image_height = self._image_dimensions(path_obj)

        if self.settings.demo_mode:
            demo_hits = self.repository.get_demo_detections(path_obj.name)
            if demo_hits is not None:
                inference_ms = int((time.perf_counter() - start) * 1000)
                scene_assessment = self._scene_assessment(path_obj, demo_hits)
                return {
                    "image_id": image_id,
                    "road_id": road_id,
                    "detections": demo_hits,
                    "model": self.model_name,
                    "inference_ms": inference_ms,
                    "image_width": image_width,
                    "image_height": image_height,
                    **scene_assessment,
                }

        if self.model is not None:
            try:
                result = self.model.predict(source=image_path, imgsz=640, conf=0.3, verbose=False)
                parsed = self._parse_yolo_result(result)
                inference_ms = int((time.perf_counter() - start) * 1000)
                scene_assessment = self._scene_assessment(path_obj, parsed)
                return {
                    "image_id": image_id,
                    "road_id": road_id,
                    "detections": parsed,
                    "model": self.model_name,
                    "inference_ms": inference_ms,
                    "image_width": image_width,
                    "image_height": image_height,
                    **scene_assessment,
                }
            except Exception:
                pass

        fallback = self._synthetic_detection(image_path)
        inference_ms = int((time.perf_counter() - start) * 1000)
        scene_assessment = self._scene_assessment(path_obj, fallback)
        return {
            "image_id": image_id,
            "road_id": road_id,
            "detections": fallback,
            "model": self.model_name,
            "inference_ms": inference_ms,
            "image_width": image_width,
            "image_height": image_height,
            **scene_assessment,
        }

    def _parse_yolo_result(self, result: list[Any]) -> list[dict[str, Any]]:
        if not result:
            return []

        parsed: list[dict[str, Any]] = []
        names = result[0].names
        for box in result[0].boxes:
            cls_id = int(box.cls[0].item())
            label = names.get(cls_id, "damage").lower()
            if "pothole" in label:
                mapped = "pothole"
            elif "crack" in label:
                mapped = "crack"
            else:
                mapped = "pothole"

            confidence = float(box.conf[0].item())
            x1, y1, x2, y2 = [float(v) for v in box.xyxy[0].tolist()]
            area = max(1.0, (x2 - x1) * (y2 - y1))
            severity = self._severity_from_area(area)
            parsed.append(
                {
                    "label": mapped,
                    "confidence": round(confidence, 2),
                    "severity": severity,
                    "bbox": [round(x1), round(y1), round(x2), round(y2)],
                }
            )
        return parsed

    @staticmethod
    def _severity_from_area(area: float) -> str:
        if area > 28000:
            return "high"
        if area > 9000:
            return "medium"
        return "low"

    def _synthetic_detection(self, image_path: str) -> list[dict[str, Any]]:
        try:
            image = Image.open(image_path).convert("RGB")
            width, height = image.size
            gray = np.asarray(image.convert("L"), dtype=np.float32)
            rgb = np.asarray(image, dtype=np.float32)
        except Exception:
            return []

        if self._looks_like_non_road_image(gray, rgb):
            return []

        return self._heuristic_pothole_detection(gray, width, height)

    @staticmethod
    def _looks_like_non_road_image(gray: np.ndarray, rgb: np.ndarray) -> bool:
        if gray.size == 0:
            return True

        normalized = gray / 255.0
        overall_mean = float(normalized.mean())
        overall_std = float(normalized.std())
        dark_ratio = float((normalized < 0.18).mean())

        border = max(1, min(gray.shape[0], gray.shape[1]) // 10)
        border_mask = np.zeros_like(normalized, dtype=bool)
        border_mask[:border, :] = True
        border_mask[-border:, :] = True
        border_mask[:, :border] = True
        border_mask[:, -border:] = True
        center_mask = ~border_mask

        border_mean = float(normalized[border_mask].mean()) if border_mask.any() else overall_mean
        center_mean = float(normalized[center_mask].mean()) if center_mask.any() else overall_mean

        rgb_norm = rgb / 255.0
        channel_range = rgb_norm.max(axis=2) - rgb_norm.min(axis=2)
        saturation_ratio = float((channel_range > 0.28).mean())

        center_active = float((normalized[center_mask] > 0.32).mean()) if center_mask.any() else 0.0
        border_active = float((normalized[border_mask] > 0.32).mean()) if border_mask.any() else 0.0

        if dark_ratio > 0.72 and overall_mean < 0.36:
            return True

        if border_mean < 0.12 and center_mean > 0.22 and saturation_ratio > 0.09:
            return True

        if center_active > 0.12 and border_active < 0.05 and overall_std > 0.18 and overall_mean < 0.38:
            return True

        return False

    @staticmethod
    def _heuristic_pothole_detection(gray: np.ndarray, width: int, height: int) -> list[dict[str, Any]]:
        if width < 80 or height < 80:
            return []

        x_start = max(0, int(width * 0.12))
        x_end = min(width, int(width * 0.88))
        y_start = max(0, int(height * 0.34))
        y_end = height
        roi = gray[y_start:y_end, x_start:x_end]
        if roi.size == 0:
            return []

        roi_mean = float(roi.mean())
        roi_std = float(roi.std())
        upper = gray[: max(1, y_start), :] if y_start > 0 else gray
        if upper.size == 0:
            upper = gray
        surrounding_mean = float(upper.mean())

        dark_score = surrounding_mean - roi_mean
        if dark_score < 5 and roi_std < 16:
            return []

        threshold = min(roi_mean - (roi_std * 0.25), surrounding_mean - 4)
        threshold = max(0.0, threshold)
        mask = roi < threshold
        dark_pixels = int(mask.sum())
        min_pixels = max(60, int(width * height * 0.008))
        if dark_pixels < min_pixels:
            return []

        ys, xs = np.where(mask)
        if xs.size == 0 or ys.size == 0:
            return []

        x1 = x_start + int(xs.min())
        x2 = x_start + int(xs.max())
        y1 = y_start + int(ys.min())
        y2 = y_start + int(ys.max())

        box_width = max(1, x2 - x1)
        box_height = max(1, y2 - y1)
        center_x = ((x1 + x2) / 2.0) / width
        center_y = ((y1 + y2) / 2.0) / height
        if center_y < 0.42:
            return []
        if abs(center_x - 0.5) > 0.38 and dark_score < 10:
            return []

        area = float(box_width * box_height)
        if area > 32000 or dark_score > 20:
            severity = "high"
            confidence = 0.92
        elif area > 12000 or dark_score > 12:
            severity = "medium"
            confidence = 0.84
        else:
            severity = "low"
            confidence = 0.74

        return [
            {
                "label": "pothole",
                "confidence": confidence,
                "severity": severity,
                "bbox": [x1, y1, x2, y2],
            }
        ]

    @staticmethod
    def _image_dimensions(path_obj: Path) -> tuple[int, int]:
        try:
            image = Image.open(path_obj)
            return image.size
        except Exception:
            return 640, 360

    def _scene_assessment(self, path_obj: Path, detections: list[dict[str, Any]]) -> dict[str, Any]:
        try:
            image = Image.open(path_obj).convert("RGB")
            gray = np.asarray(image.convert("L"), dtype=np.float32)
            rgb = np.asarray(image, dtype=np.float32)
            if self._looks_like_non_road_image(gray, rgb):
                return {
                    "scene_status": "not_road",
                    "scene_message": "This image does not look like a road photo. Please upload a clear road image showing the damaged area.",
                    "needs_reupload": True,
                }
        except Exception:
            pass

        name = path_obj.stem.lower()
        roadish_keywords = ("road", "street", "lane", "highway", "bridge", "pavement", "asphalt", "tar", "tarmac")
        non_road_keywords = (
            "selfie",
            "portrait",
            "person",
            "face",
            "food",
            "room",
            "indoor",
            "pet",
            "dog",
            "cat",
            "tree",
            "sky",
            "flower",
            "landscape",
        )

        if any(keyword in name for keyword in non_road_keywords) and not any(
            keyword in name for keyword in roadish_keywords
        ):
            return {
                "scene_status": "not_road",
                "scene_message": "This image does not look like a road photo. Please upload a clear road image showing the damaged area.",
                "needs_reupload": True,
            }

        if not detections:
            return {
                "scene_status": "no_issue",
                "scene_message": "No visible pothole or crack was detected. Please reupload a clearer road photo if the damage is still present.",
                "needs_reupload": True,
            }

        high_confidence = any(item.get("confidence", 0) >= 0.7 for item in detections)
        return {
            "scene_status": "issue_detected" if high_confidence else "uncertain",
            "scene_message": "Road damage detected." if high_confidence else "Possible road damage detected, but the image is not fully clear.",
            "needs_reupload": False,
        }
