import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-webhook-secret",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload = await req.json();
    const aiServiceUrl = Deno.env.get("AI_SERVICE_URL") || "http://localhost:8000";
    const webhookSecret = Deno.env.get("WEBHOOK_SECRET") || "";

    // Forward completed sessions to AI service
    if (payload.record && payload.record.session_status === "completed") {
      const response = await fetch(`${aiServiceUrl}/webhook/session-completed`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Webhook-Secret": webhookSecret,
        },
        body: JSON.stringify({
          session_id: payload.record.session_id,
          user_id: payload.record.user_id,
          session_status: payload.record.session_status,
          created_at: payload.record.created_at,
          started_at: payload.record.started_at,
          ended_at: payload.record.ended_at,
        }),
      });

      const result = await response.json();
      return new Response(JSON.stringify({ forwarded: true, ai_response: result }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ forwarded: false, reason: "Session not completed" }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
