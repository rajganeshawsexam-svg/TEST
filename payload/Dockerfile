FROM node:18 AS build
WORKDIR /app
COPY package.json ./
RUN npm install
COPY . .
RUN npm run build || true

FROM node:18
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /app ./
RUN npm install --only=production
EXPOSE 3000
CMD ["node", "index.js"]
