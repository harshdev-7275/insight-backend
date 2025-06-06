# Build stage
FROM node:20-slim AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install ALL dependencies (including devDependencies) for building
RUN npm ci

# Copy source code
COPY . .

# Build TypeScript code
RUN npm run build

# Production stage
FROM node:20-slim

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install production dependencies only
RUN npm ci --only=production

# Copy built files from builder stage
COPY --from=builder /app/dist ./dist

# Copy migrations directory
COPY --from=builder /app/src/config/migrations ./dist/config/migrations

# Create logs directory
RUN mkdir -p logs

# Expose port (adjust if needed)
EXPOSE 10000

# Create a startup script that waits for PostgreSQL
RUN echo '#!/bin/sh\n\
echo "Waiting for PostgreSQL to be ready..."\n\
while ! nc -z $POSTGRES_HOST $POSTGRES_PORT; do\n\
  sleep 1\n\
done\n\
echo "PostgreSQL is ready!"\n\
\n\
echo "Resetting database schema..."\n\
PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"\n\
\n\
echo "Running database migrations..."\n\
npm run migrate\n\
\n\
echo "Starting application..."\n\
node dist/index.js' > /app/start.sh && \
chmod +x /app/start.sh

# Install netcat and postgresql-client for the wait script
RUN apt-get update && apt-get install -y netcat-traditional postgresql-client && rm -rf /var/lib/apt/lists/*

# Start the application with initialization
CMD ["/app/start.sh"] 