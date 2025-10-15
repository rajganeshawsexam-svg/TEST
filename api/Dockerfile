FROM node:18
COPY package.json package-lock.json* ./
RUN npm install
COPY . .
RUN npm install --only=production
EXPOSE 3001
CMD ["node", "index.js"]
