# Example scheduled job image. Node only: no npm packages needed.
FROM node:24-alpine
WORKDIR /app
COPY app/ .
CMD ["sh", "-c", "node scripts/build-example.mjs && node upload-blob.mjs"]
