#!/bin/bash
# Generates web/config.js from environment variables at Vercel build time.
# Run automatically by Vercel via vercel.json buildCommand.
# Never commit the generated web/config.js — it is gitignored.
set -e

: "${SUPABASE_URL:?SUPABASE_URL must be set in Vercel Environment Variables}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY must be set in Vercel Environment Variables}"

cat > web/config.js <<EOF
window.SUPABASE_URL      = '${SUPABASE_URL}';
window.SUPABASE_ANON_KEY = '${SUPABASE_ANON_KEY}';
EOF

echo "web/config.js generated from environment variables"
