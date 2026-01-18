#!/bin/bash


echo "═══════════════════════════════════════════════════════"
echo "🔐 SECURITY AUDIT - Checking for sensitive data in Git"
echo "═══════════════════════════════════════════════════════"
echo ""

# Check .gitignore exists and has proper entries
echo "1️⃣ Checking .gitignore configuration..."
if [ -f .gitignore ]; then
    echo "✅ .gitignore exists"
    echo ""
    echo "Current .gitignore contents:"
    cat .gitignore
else
    echo "❌ .gitignore missing!"
fi

echo ""
echo "2️⃣ Checking if secrets are tracked in Git..."
git ls-files | grep -E "(secret|\.env$|credentials|password|mongo.*uri)" && echo "⚠️  WARNING: Potential secrets found in tracked files!" || echo "✅ No obvious secrets in tracked files"

echo ""
echo "3️⃣ Checking for hardcoded credentials in code..."
grep -r "mongodb://" application/ --include="*.js" --include="*.yaml" --exclude-dir=node_modules | grep -v "process.env" | grep -v "localhost" | head -5

echo ""
echo "4️⃣ Verifying secret.yaml is NOT in Git..."
git ls-files | grep "02-secret.yaml" && echo "❌ DANGER: secret.yaml is tracked!" || echo "✅ secret.yaml not tracked"

echo ""
echo "5️⃣ Checking what's in staging area..."
git diff --cached --name-only

echo ""
echo "═══════════════════════════════════════════════════════"
