#!/bin/bash
# ==============================================================================
# Automated Database Recovery Script for Boutique Microservices
# This script restores all databases from the latest backup or seed dump.
# Usage:
#   ./automated-recovery.sh [local | k8s]
# ==============================================================================

set -e

MODE=${1:-k8s}

echo "=================================================="
echo " Starting Automated Database Recovery ($MODE mode)"
echo "=================================================="

if [ "$MODE" == "local" ]; then
    DB_HOST="localhost"
    DB_PORT="5432"
    DB_USER="postgres"
    export PGPASSWORD="postgres123"

    echo "1. Checking database connection on $DB_HOST:$DB_PORT..."
    until pg_isready -h $DB_HOST -p $DB_PORT -U $DB_USER >/dev/null 2>&1; do
        echo "Waiting for PostgreSQL..."
        sleep 2
    done

    echo "2. Re-creating core databases if deleted..."
    for DB in auth_db products_db orders_db users_db; do
        psql -h $DB_HOST -p $DB_PORT -U $DB_USER -c "SELECT 1 FROM pg_database WHERE datname='$DB'" | grep -q 1 || \
        psql -h $DB_HOST -p $DB_PORT -U $DB_USER -c "CREATE DATABASE $DB;"
    done

    echo "3. Restoring schema and data from boutique_full.sql..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    psql -h $DB_HOST -p $DB_PORT -U $DB_USER -f "$SCRIPT_DIR/boutique_full.sql"

    echo "4. Verification:"
    PRODUCT_COUNT=$(psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d products_db -t -c "SELECT count(*) FROM products;" | xargs)
    echo "SUCCESS: products_db restored with $PRODUCT_COUNT products."

elif [ "$MODE" == "k8s" ]; then
    echo "1. Applying automated database restore job in Kubernetes..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    kubectl delete job boutique-db-restore -n boutique --ignore-not-found=true
    kubectl apply -f "$SCRIPT_DIR/restore-job.yml" -n boutique

    echo "2. Waiting for restore Job to complete..."
    kubectl wait --for=condition=complete --timeout=120s job/boutique-db-restore -n boutique

    echo "3. Recovery Job logs:"
    kubectl logs -n boutique -l job-name=boutique-db-restore --tail=20

    echo "SUCCESS: Database disaster recovery complete in Kubernetes boutique namespace!"
fi
