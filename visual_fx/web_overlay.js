(() => {
  "use strict";
  const overlay = document.createElement("canvas");
  overlay.id = "scorchnova-sci-fi-sky";
  overlay.setAttribute("aria-hidden", "true");
  overlay.style.cssText = "position:fixed;pointer-events:none;z-index:4;display:none;";
  document.body.appendChild(overlay);
  const ctx = overlay.getContext("2d", {alpha:true});
  let start = performance.now();
  function render(now) {
    const game = document.querySelector("canvas:not(#scorchnova-sci-fi-sky)");
    if (!game || !ctx) { requestAnimationFrame(render); return; }
    const r = game.getBoundingClientRect();
    if (r.width < 100 || r.height < 100) { overlay.style.display="none"; requestAnimationFrame(render); return; }
    overlay.style.display="block";
    overlay.style.left=r.left+"px"; overlay.style.top=r.top+"px";
    overlay.style.width=r.width+"px"; overlay.style.height=r.height+"px";
    const dpr=Math.min(devicePixelRatio||1,1.5);
    const pw=Math.round(r.width*dpr),ph=Math.round(r.height*dpr);
    if(overlay.width!==pw||overlay.height!==ph){overlay.width=pw;overlay.height=ph;}
    ctx.setTransform(dpr,0,0,dpr,0,0);
    const w=r.width,h=r.height,t=(now-start)/1000;
    ctx.clearRect(0,0,w,h);
    // Transparent violet upper-atmosphere tint.
    const sky=ctx.createLinearGradient(0,0,0,h*.42);
    sky.addColorStop(0,"rgba(91,53,171,.21)");
    sky.addColorStop(.6,"rgba(92,80,184,.10)");
    sky.addColorStop(1,"rgba(25,20,90,0)");
    ctx.fillStyle=sky;ctx.fillRect(0,0,w,h*.42);
    // Rounded cartoon clouds, kept behind the playable landscape.
    for(let i=0;i<5;i++){
      const drift=(t*(1.3+i*.3)+i*w*.24)%(w+140)-70;
      const cy=h*(.30+(i%3)*.035);
      ctx.fillStyle="rgba(194,184,255,.22)";
      for(let puff=0;puff<4;puff++){
        ctx.beginPath();
        ctx.ellipse(drift+(puff-1.5)*17,cy+Math.sin(puff*1.5)*3,23+(puff%2)*6,10+(puff%2)*3,0,0,Math.PI*2);
        ctx.fill();
      }
      ctx.strokeStyle="rgba(227,210,255,.27)";ctx.lineWidth=1.3;
      ctx.beginPath();ctx.ellipse(drift,cy+5,45,11,0,Math.PI*.08,Math.PI*.9);ctx.stroke();
    }
    // Alien ringed planet, deliberately prominent and easy to verify.
    const x=w*.76,y=h*.39,rad=Math.max(13,Math.min(32,h*.055));
    const halo=ctx.createRadialGradient(x,y,rad*.6,x,y,rad*3);
    halo.addColorStop(0,"rgba(105,113,255,.24)");halo.addColorStop(1,"rgba(105,113,255,0)");
    ctx.fillStyle=halo;ctx.beginPath();ctx.arc(x,y,rad*3,0,Math.PI*2);ctx.fill();
    const globe=ctx.createRadialGradient(x-rad*.35,y-rad*.35,1,x,y,rad);
    globe.addColorStop(0,"rgba(182,210,255,.93)");
    globe.addColorStop(.5,"rgba(103,109,226,.9)");
    globe.addColorStop(1,"rgba(55,37,142,.9)");
    ctx.fillStyle=globe;ctx.beginPath();ctx.arc(x,y,rad,0,Math.PI*2);ctx.fill();
    ctx.strokeStyle="rgba(192,123,255,.78)";ctx.lineWidth=Math.max(1.4,rad*.10);
    ctx.beginPath();ctx.ellipse(x,y,rad*1.72,rad*.42,-.23,0,Math.PI*2);ctx.stroke();
    // Two translucent parallax ridges, never touch the actual terrain.
    for(let layer=0;layer<2;layer++){
      const base=h*(.42+layer*.048);
      ctx.beginPath();ctx.moveTo(0,base);
      for(let i=0;i<=40;i++){
        const xx=w*i/40;
        const yy=base-h*(.025+layer*.015)*(1+Math.sin(i*.56+layer*2+t*.025)*.65+Math.sin(i*.27+layer)*.45);
        ctx.lineTo(xx,yy);
      }
      ctx.lineTo(w,base);ctx.closePath();
      ctx.fillStyle=layer?"rgba(118,98,194,.21)":"rgba(149,116,208,.24)";ctx.fill();
    }
    // Sci-fi beacon glints.
    for(let i=0;i<8;i++){
      const bx=w*(i+.5)/8,by=h*(.44+(i%3)*.018),a=.35+.3*Math.sin(t*1.3+i*2);
      ctx.fillStyle="rgba(91,227,255,"+a+")";
      ctx.beginPath();ctx.arc(bx,by,1.4,0,Math.PI*2);ctx.fill();
    }
    requestAnimationFrame(render);
  }
  requestAnimationFrame(render);
})();
