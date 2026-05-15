// Web implementation
import 'dart:html' as html;

String? openInNewTab(String url) {
  html.window.open(url, '_blank');
  return 'ok';
}
