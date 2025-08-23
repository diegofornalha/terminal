# Development stage
FROM node:18-alpine AS development

WORKDIR /app

# Copy package files
COPY package.json ./
RUN npm install

# Copy application code
COPY . .

EXPOSE 3005

CMD ["npm", "run", "dev:no-open"]

# Builder stage
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package.json ./
RUN npm install

# Copy application code
COPY . .

# Build the application
RUN npm run build

# Production stage
FROM node:18-alpine AS production

WORKDIR /app

# Copy package files
COPY package.json ./
RUN npm install --only=production

# Copy built application from builder
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/next.config.js ./

EXPOSE 3005

CMD ["npm", "start"]