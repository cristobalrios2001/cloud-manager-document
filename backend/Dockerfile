# ---------- Etapa 1: compilar TypeScript ----------
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build && ls -la dist && test -f dist/main.js

# ---------- Etapa 2: solo dependencias de producción ----------
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# ---------- Etapa 3: imagen final liviana ----------
FROM node:20-alpine AS runner
ENV NODE_ENV=production
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY package*.json ./

# Usuario sin privilegios (ya existe en la imagen de node)
USER node

EXPOSE 4000
CMD ["node", "dist/main.js"]