FROM node:20.18.3-alpine3.21

WORKDIR /app

COPY --chown=node:node server.js server.js

ENV NODE_ENV=production
ENV PORT=8080

USER node

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
CMD node -e "fetch('http://127.0.0.1:8080/health').then(r => process.exit(r.ok ? 0 :1)).catch(() => process.exit(1))"

CMD ["node", "server.js"]
