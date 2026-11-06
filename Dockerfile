FROM node:18-alpine

WORKDIR /app
COPY --chown=node:node server/ ./server/
COPY --chown=node:node shared/ ./shared/
COPY --chown=node:node web/ ./web/

ENV PORT=3000 \
    HOST=0.0.0.0
# OPENAI_API_KEY / OPENAI_BASE_URL / OPENAI_MODEL 用 docker run -e 或 compose env_file 注入，不要写进镜像
# LLM key 留空时服务只用内置规则引擎，仍然完整可用

EXPOSE 3000
USER node
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD node -e 'const p=process.env.PORT||3000;fetch("http://127.0.0.1:"+p+"/api/health").then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))'

CMD ["node", "server/index.js"]
