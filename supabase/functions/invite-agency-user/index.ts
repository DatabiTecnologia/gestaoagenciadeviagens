import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{
  status,headers:{"content-type":"application/json","access-control-allow-origin":"*"}
});

Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS") return new Response("ok",{headers:{"access-control-allow-origin":"*","access-control-allow-headers":"authorization,content-type"}});
  if(req.method!=="POST") return json({error:"Método não permitido"},405);

  const url=Deno.env.get("SUPABASE_URL");
  const serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authorization=req.headers.get("authorization");
  if(!url||!serviceKey||!authorization) return json({error:"Não autorizado"},401);

  const callerResponse=await fetch(`${url}/auth/v1/user`,{headers:{authorization,apikey:serviceKey}});
  if(!callerResponse.ok) return json({error:"Sessão inválida"},401);
  const caller=await callerResponse.json();

  const body=await req.json();
  const {organization_id,email,full_name,role="seller",phone=null,commission_percent=0}=body;
  if(!organization_id||!email||!full_name) return json({error:"Dados obrigatórios ausentes"},400);

  const membershipResponse=await fetch(
    `${url}/rest/v1/memberships?organization_id=eq.${encodeURIComponent(organization_id)}&user_id=eq.${caller.id}&active=eq.true&select=role`,
    {headers:{authorization:`Bearer ${serviceKey}`,apikey:serviceKey}}
  );
  const memberships=await membershipResponse.json();
  if(!Array.isArray(memberships)||!memberships.some((m)=>["owner","admin"].includes(m.role)))
    return json({error:"Apenas administradores podem criar usuários"},403);

  const inviteResponse=await fetch(`${url}/auth/v1/invite`,{
    method:"POST",
    headers:{authorization:`Bearer ${serviceKey}`,apikey:serviceKey,"content-type":"application/json"},
    body:JSON.stringify({email,data:{full_name}})
  });
  const invited=await inviteResponse.json();
  if(!inviteResponse.ok) return json({error:invited.msg||invited.message||"Falha ao enviar convite"},400);

  const profileResponse=await fetch(`${url}/rest/v1/profiles`,{
    method:"POST",
    headers:{authorization:`Bearer ${serviceKey}`,apikey:serviceKey,"content-type":"application/json",prefer:"resolution=merge-duplicates"},
    body:JSON.stringify({id:invited.id,full_name,phone})
  });
  if(!profileResponse.ok) return json({error:"Convite criado, mas o perfil não pôde ser salvo"},500);

  const linkResponse=await fetch(`${url}/rest/v1/memberships`,{
    method:"POST",
    headers:{authorization:`Bearer ${serviceKey}`,apikey:serviceKey,"content-type":"application/json"},
    body:JSON.stringify({organization_id,user_id:invited.id,role,commission_percent})
  });
  if(!linkResponse.ok) return json({error:"Convite criado, mas o vínculo com a agência falhou"},500);
  return json({id:invited.id,email,status:"invited"},201);
});
