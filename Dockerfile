FROM node:18 as builder

WORKDIR /calcom

ARG NEXT_PUBLIC_LICENSE_CONSENT=0
ARG CALCOM_TELEMETRY_DISABLED=1
ARG DATABASE_URL=postgresql://pg:password@localhost:5432/db
ARG NEXTAUTH_SECRET=EI4qqDpcfdvf4A+0aQEEx8JjHxHSy4uWiZw/F32K+pA=
ARG CALENDSO_ENCRYPTION_KEY=0zfLtY99wjeLnsM7qsa8xsT+Q0oSgnOL
ARG MAX_OLD_SPACE_SIZE=4096

ENV NEXT_PUBLIC_WEBAPP_URL=http://NEXT_PUBLIC_WEBAPP_URL_PLACEHOLDER \
    NEXT_PUBLIC_LICENSE_CONSENT=$NEXT_PUBLIC_LICENSE_CONSENT \
    CALCOM_TELEMETRY_DISABLED=$CALCOM_TELEMETRY_DISABLED \
    DATABASE_URL=$DATABASE_URL \
    DATABASE_DIRECT_URL=$DATABASE_URL \
    NEXTAUTH_SECRET=${NEXTAUTH_SECRET} \
    CALENDSO_ENCRYPTION_KEY=${CALENDSO_ENCRYPTION_KEY} \
    NODE_OPTIONS=--max-old-space-size=${MAX_OLD_SPACE_SIZE}

COPY package.json yarn.lock .yarnrc.yml playwright.config.ts turbo.json git-init.sh git-setup.sh ./
COPY .yarn ./.yarn
COPY apps/web ./apps/web
COPY packages ./packages
COPY tests ./tests

RUN yarn config set httpTimeout 1200000 && \
    npx turbo prune --scope=@calcom/web --docker && \
    yarn install

RUN yarn turbo run build --filter=@calcom/web

RUN rm -rf node_modules/.cache .yarn/cache apps/web/.next/cache

FROM node:18 as builder-two

WORKDIR /calcom
ARG NEXT_PUBLIC_WEBAPP_URL=http://localhost:3000

ENV NODE_ENV production

COPY package.json .yarnrc.yml yarn.lock turbo.json ./
COPY .yarn ./.yarn
COPY --from=builder /calcom/node_modules ./node_modules
COPY --from=builder /calcom/packages ./packages
COPY --from=builder /calcom/apps/web ./apps/web
COPY --from=builder /calcom/packages/prisma/schema.prisma ./prisma/schema.prisma
COPY docker_scripts scripts

# Save value used during this build stage. If NEXT_PUBLIC_WEBAPP_URL and BUILT_NEXT_PUBLIC_WEBAPP_URL differ at
# run-time, then start.sh will find/replace static values again.
ENV NEXT_PUBLIC_WEBAPP_URL=$NEXT_PUBLIC_WEBAPP_URL \
    BUILT_NEXT_PUBLIC_WEBAPP_URL=$NEXT_PUBLIC_WEBAPP_URL

RUN scripts/replace-placeholder.sh http://NEXT_PUBLIC_WEBAPP_URL_PLACEHOLDER ${NEXT_PUBLIC_WEBAPP_URL}

FROM node:18 as runner


WORKDIR /calcom
COPY --from=builder-two /calcom ./
ARG NEXT_PUBLIC_WEBAPP_URL=http://localhost:3000
ENV NEXT_PUBLIC_WEBAPP_URL=$NEXT_PUBLIC_WEBAPP_URL \
    BUILT_NEXT_PUBLIC_WEBAPP_URL=$NEXT_PUBLIC_WEBAPP_URL

ENV NODE_ENV production
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=30s --retries=5 \
    CMD wget --spider http://localhost:3000 || exit 1

CMD ["/calcom/scripts/start.sh"]
