# Stage 1: Build React Production Assets
FROM node:20-alpine AS builder

WORKDIR /app

# Prevent React Scripts from failing on warnings or running out of memory during Webpack compilation
ENV CI=false
ENV GENERATE_SOURCEMAP=false
ENV DISABLE_ESLINT_PLUGIN=true
ENV TSC_COMPILE_ON_ERROR=true
ENV NODE_OPTIONS="--max-old-space-size=2048"

COPY package*.json ./

# Pin schema-utils 3.1.1, ajv 6.12.6, and ajv-keywords 3.5.2
# schema-utils v3 does not use ajv-formats, eliminating the 'ajv/dist/compile/codegen' error completely
RUN node -e " \
  const fs = require('fs'); \
  const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8')); \
  if (pkg.dependencies) { \
    delete pkg.dependencies['ajv']; \
    delete pkg.dependencies['ajv-keywords']; \
    delete pkg.dependencies['schema-utils']; \
  } \
  pkg.overrides = Object.assign({}, pkg.overrides, { \
    'schema-utils': '3.1.1', \
    'ajv': '6.12.6', \
    'ajv-keywords': '3.5.2' \
  }); \
  fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2)); \
"

RUN npm install --legacy-peer-deps

COPY . .
RUN npm run build

# Stage 2: Lightweight Production Web Server
FROM nginx:1.27-alpine

COPY --from=builder /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:80/ || exit 1

CMD ["nginx", "-g", "daemon off;"]