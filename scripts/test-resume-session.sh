#!/usr/bin/env bash
# Test avec --resume pour voir si on peut garder une session

set -e

echo "🧪 Test avec --resume (session persistante)"
echo "============================================"
echo ""

# Charger CURSOR_API_KEY
if [ -f .env ]; then
    export $(grep "^CURSOR_API_KEY=" .env | xargs 2>/dev/null || true)
fi

# Test 1: Voir si --resume fonctionne avec --print
echo "Test 1: --resume avec --print"
echo "------------------------------"
echo "user: Bonjour" | cursor-agent --print --model gpt-5.2 --resume 2>&1 | head -5
echo ""

# Test 2: Lancer cursor-agent en mode interactif et voir comment communiquer
echo "Test 2: Mode interactif (sans --print)"
echo "---------------------------------------"
echo "Note: cursor-agent en mode interactif nécessite une interface TUI"
echo "Ce test vérifie si on peut l'utiliser en arrière-plan"
echo ""

# Test 3: Utiliser un script Python simple pour tester
echo "Test 3: Script Python pour processus persistant"
echo "-------------------------------------------------"
cat > /tmp/test_persistent.py << 'PYEOF'
#!/usr/bin/env python3
import subprocess
import time
import sys

print("Lancement de cursor-agent en arrière-plan...")
# Lancer cursor-agent sans --print pour voir s'il reste en vie
proc = subprocess.Popen(
    ["cursor-agent", "--model", "gpt-5.2"],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True
)

print(f"PID: {proc.pid}")
print("Attente de 2 secondes...")
time.sleep(2)

# Vérifier si toujours en vie
if proc.poll() is None:
    print("✅ Processus toujours en vie")
    
    # Essayer d'envoyer un prompt
    print("Envoi du prompt 'user: Bonjour'...")
    try:
        proc.stdin.write("user: Bonjour\n")
        proc.stdin.flush()
        
        # Lire avec timeout
        import select
        if sys.platform != 'win32':
            import select
            ready, _, _ = select.select([proc.stdout], [], [], 5)
            if ready:
                output = proc.stdout.read(1000)
                print(f"Réponse: {output[:200]}")
            else:
                print("Timeout - pas de réponse")
    except Exception as e:
        print(f"Erreur: {e}")
    
    # Nettoyer
    proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()
else:
    print(f"❌ Processus terminé avec code: {proc.returncode}")
    stderr = proc.stderr.read()
    print(f"Stderr: {stderr[:500]}")
PYEOF

chmod +x /tmp/test_persistent.py
python3 /tmp/test_persistent.py

rm -f /tmp/test_persistent.py

echo ""
echo "=================================================="
echo "📝 Conclusion:"
echo "   Si cursor-agent peut rester en vie en mode"
echo "   interactif, on peut implémenter un processus"
echo "   persistant dans Python."
echo ""

