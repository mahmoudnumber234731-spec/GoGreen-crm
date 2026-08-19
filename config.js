// ============================================================
// إعدادات الاتصال بقاعدة البيانات — الملف ده بس اللي هتحط فيه بياناتك
// ============================================================
const SUPABASE_URL = "https://bgjnnvkeuvvefhnctlfj.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJnam5udmtldXZ2ZWZobmN0bGZqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcxNTczOTYsImV4cCI6MjEwMjczMzM5Nn0.5tSYIgdYrwSVCxbbJzjUgNUu7CnnHiDjeCHSvX_HPwk";

const sb = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// يتأكد إن فيه مستخدم مسجّل دخول، ولو لأ يرجّعه لصفحة الدخول
async function requireAuth() {
  const { data: { session } } = await sb.auth.getSession();
  if (!session) {
    window.location.href = "index.html";
    return null;
  }
  return session;
}

// يحدّث وقت آخر ظهور للمستخدم كل شوية (عشان نظام أونلاين/أوفلاين)
function startHeartbeat(userId) {
  const beat = () => sb.from("profiles").update({ last_seen: new Date().toISOString() }).eq("id", userId);
  beat();
  return setInterval(beat, 20000); // كل 20 ثانية
}

// مستخدم يعتبر "أونلاين" لو آخر ظهور له كان قبل أقل من 60 ثانية
function isOnline(lastSeen) {
  if (!lastSeen) return false;
  return (Date.now() - new Date(lastSeen).getTime()) < 60000;
}
