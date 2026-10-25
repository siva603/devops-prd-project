# ---------- Stage 1: build the React app ----------
FROM node:20-alpine AS builder

WORKDIR /app

ENV CI=false
ENV GENERATE_SOURCEMAP=false
ENV DISABLE_ESLINT_PLUGIN=true
ENV TSC_COMPILE_ON_ERROR=true
ENV NODE_OPTIONS="--max-old-space-size=2048"

COPY package*.json ./
RUN npm install --legacy-peer-deps

COPY . .
RUN npm run build

# Stop the build, with a clear message, if the app was not really built
RUN set -e; \
    if [ -f build/index.html ]; then OUT=build; \
    elif [ -f dist/index.html ]; then OUT=dist; \
    else echo "ERROR: npm run build did not create index.html"; ls -la build 2>&1; exit 1; fi; \
    echo "Build output folder: $OUT"; \
    mkdir -p /out && cp -r "$OUT"/. /out/

# ---------- Stage 2: Nginx ----------
FROM nginx:1.27-alpine

RUN rm -rf /usr/share/nginx/html/*

COPY --from=builder /out/ /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf

RUN test -f /usr/share/nginx/html/index.html \
    && chmod -R a+rX /usr/share/nginx/html \
    && ls -la /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -q --spider http://127.0.0.1:80/ || exit 1

CMD ["nginx", "-g", "daemon off;"]