FROM node:20-slim
WORKDIR /usr/src/app

# Install dependencies
COPY package.json package-lock.json* ./
RUN npm ci --only=production || npm install --only=production

# Copy source
COPY . .

ENV NODE_ENV=production
ENV PORT=8000

EXPOSE 8000

CMD ["node", "src/server.js"]
