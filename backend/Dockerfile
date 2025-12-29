FROM node:20-alpine

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install --only=production

COPY src ./src

ENV NODE_ENV=production
EXPOSE 3000

USER node
CMD ["node", "src/index.js"]
