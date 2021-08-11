//version "2.4"

class ScopeHandler : EventHandler
{
	// Interpolation data
	private ui Vector2 oldScale;
	private ui double oldRotation;
	private ui Vector3 oldPos;
	
	private ui double oldFOV;
	private ui Shape2D circle;
	private ui TextureID lens;
	
	// DEBUG
	bool bSize;
	override void WorldTick()
	{
		let psp = players[consoleplayer].GetPSprite(PSP_WEAPON);
		if (psp.scale.x >= 1.5)
			bSize = false;
		else if (psp.scale.x <= 0.75)
			bSize = true;
			
		if (bSize)
			psp.scale += (0.01, 0.01);
		else
			psp.scale -= (0.01, 0.01);
			
		//psp.rotation += 1;
		psp.bInterpolate = true;
		psp.pivot = (0,0);
		psp.bPivotPercent = true;
		psp.HAlign = PSPA_CENTER;
		psp.VAlign = PSPA_CENTER;
	}
	// END DEBUG
	
	override void UITick()
	{
		if (!circle)
			circle = CreateCircle();
		if (!lens.IsValid())
			lens = TexMan.CheckForTexture("SCAMTEX1", TexMan.Type_Any);
		
		let weap = ScopedWeapon(players[consoleplayer].ReadyWeapon);
		if (!weap)
		{
			oldRotation = 0;
			oldScale = (1,1);
			oldFov = 0;
			return;
		}
		
		// Update scope if weapon camera FOV changed
		double fov = weap.CameraFOV;
		if (fov != oldFOV && weap.ShouldDrawScope())
			TexMan.SetCameraToTexture(weap.GetCamera(), "SCAMTEX1", fov);
		
		oldFOV = fov;
		let psp = players[consoleplayer].GetPSprite(PSP_WEAPON);
		oldRotation = psp.rotation;
		oldScale = psp.scale;
	}
	
	override void RenderUnderlay(RenderEvent e)
	{
		let weap = ScopedWeapon(players[consoleplayer].ReadyWeapon);
		if (!weap || !weap.ShouldDrawScope() || automapactive)
			return;
		
		// Account for the view port
		int wOfs, hOfs, w, h;
		[wOfs, hOfs, w, h] = Screen.GetViewWindow();
		
		// Scale for PSprite coordinates to screen
		int height = Screen.GetHeight();
		Vector2 scale;
		scale.x = w / (240 * Screen.GetAspectRatio());
		scale.y = (height*w) / (Screen.GetWidth() * 200.);
		
		// Make sure scope stays proportional to resolution (based on 1920x1080) and viewport
		double multi = h / (hOfs*2. + h) * height / 1080.;
		
		// Get updated information about scope position and size
		let psp = players[consoleplayer].GetPSprite(PSP_WEAPON);
		Vector2 realPos = Lerp((psp.oldx,psp.oldy), (psp.x,psp.y), e.fracTic);
		if (psp.bMirror)
			realPos.x *= -1;
		
		bool interpolate = psp.interpolateTic || psp.bInterpolate;
		Vector2 scopeScale = interpolate ? Lerp(oldScale, psp.scale, e.fracTic) : psp.scale;
		double scopeAngle = interpolate ? -LerpFloat(oldRotation, psp.rotation, e.fracTic) : -psp.rotation;
		
		// TODO: Sprite YAdjust in fullscreen mode
		Vector2 scopePos = (wOfs + w/2 + realPos.x*scale.x, hOfs + h - 100*scale.y + realPos.y*scale.y);
		Vector2 scopeOfs = (weap.renderWidthOffset*scale.x, -(WEAPONTOP+weap.renderHeightOffset)*scale.y);
		if (psp.bMirror)
			scopeOfs.x *= -1;
		Vector2 scopeSize = TexMan.GetScaledSize(lens)*weap.scopeScale / 2 * multi;
		
		// Calculate the correct anchor point for scaling
		Vector2 pivot = psp.pivot;
		Vector2 anchor;
		switch (psp.HAlign)
		{
			case PSPA_LEFT:
				anchor.x = 0;
				break;
				
			case PSPA_RIGHT:
				anchor.x = 1;
				break;
				
			default:
				anchor.x = 0.5;
				break;
		}
		
		switch (psp.VAlign)
		{
			case PSPA_TOP:
				anchor.y = 0;
				break;
				
			case PSPA_BOTTOM:
				anchor.y = 1;
				break;
				
			default:
				anchor.y = 0.5;
				break;
		}
		
		if (psp.bFlip)
		{
			scopeAngle *= -1;
			anchor.x = 1 - anchor.x;
			pivot.x *= -1;
		}
		
		anchor -= (0.5,0.5);
		anchor *= -2;
		
		if (psp.bPivotPercent)
			pivot *= 2;
		else
		{
			pivot.x = pivot.x*scale.x / scopeSize.x;
			pivot.y = pivot.y*scale.y / scopeSize.y;
		}
		
		anchor.x -= pivot.x;
		anchor.y -= pivot.y;
		scopePos.x -= scopeSize.x*anchor.x;
		scopePos.y -= scopeSize.y*anchor.y;
		
		scopeSize.x *= scopeScale.x;
		scopeSize.y *= scopeScale.y;
		scopePos += Actor.RotateVector(scopeOfs, scopeAngle);
		
		// Make sure it can't draw outside of the view port
		int cx, cy, cw, ch;
		[cx, cy, cw, ch] = Screen.GetClipRect();
		Screen.SetClipRect(wOfs, hOfs, w, h);
		
		DrawScope(lens, false, circle, scopePos, scopeSize, anchor: anchor);
		let id = weap.GetScopeTexture();
		if (id.IsValid())
			DrawScope(id, true, circle, scopePos, scopeSize, scopeAngle, players[consoleplayer].mo.GetRenderStyle(), psp.alpha, anchor);
		
		Screen.SetClipRect(cx, cy, cw, ch);
	}
	
	// verts describes how detailed the circle of the scope is
	// more verts = higher resolution circle but higher performance cost
	ui static Shape2D CreateCircle(uint verts = 64)
	{
		Shape2D circle = new("Shape2D");
		
		double angStep = 360. / verts;
		double ang;
		for (uint i = 0; i < verts; ++i)
		{
			double c = cos(ang);
			double s = sin(ang);
			
			circle.PushVertex((c,s));
			circle.PushCoord(((c+1)/2, (s+1)/2));
			
			if (i+2 < verts)
				circle.PushTriangle(0, i+1, i+2);
			
			ang += angStep;
		}
		
		return circle;
	}
	
	ui void DrawScope(TextureID id, bool anim, Shape2D shape, Vector2 pos, Vector2 size, double ang = 0, int renderStyle = STYLE_Normal, double alpha = 1, Vector2 anchor = (0,0))
    {
		if (!shape)
			return;
		
		let transform = new("Shape2DTransform");
		transform.Translate(anchor);
		transform.Scale(size);
		transform.Rotate(ang);
		transform.Translate(pos);
		shape.SetTransform(transform);
		
		Screen.DrawShape(id, anim, shape, DTA_LegacyRenderStyle, renderStyle, DTA_Alpha, alpha);
    }
	
	ui Vector2 Lerp(Vector2 a, Vector2 b, double t)
	{
		return a*(1-t) + b*t;
	}
	
	ui double LerpFloat(double a, double b, double t)
	{
		return a*(1-t) + b*t;
	}
}

class ScopedWeapon : Weapon
{
	private bool bDrawScope;
	private ScopeCam cam;
	private Vector2 weaponBob;
	private Vector3 f, r, u;
	private Vector3 prevAngles;
	
	double renderHeightOffset;
	double renderWidthOffset;
	double scopeScale;
	string scopeTexture;
	double forwardOffset;
	double sideOffset;
	double upOffset;
	double swaySideMultiplier;
	double swayUpMultiplier;
	
	property RenderHeightOffset : renderHeightOffset;
	property RenderWidthOffset : renderWidthOffset;
	property ScopeScale : scopeScale;
	property ScopeTexture : scopeTexture;
	property ForwardOffset : forwardOffset;
	property SideOffset : sideOffset;
	property UpOffset : upOffset;
	property SwaySideMultiplier : swaySideMultiplier;
	property SwayUpMultiplier : swayUpMultiplier;
	
	Default
	{
		Weapon.Kickback 100;
		ScopedWeapon.ScopeScale 1;
		ScopedWeapon.ForwardOffset 4;
	}
	
	clearscope bool ShouldDrawScope() const
	{
		return bDrawScope;
	}
	
	clearscope ScopeCam GetCamera() const
	{
		return cam;
	}
	
	clearscope Vector2 WeaponBobOffset() const
	{
		return weaponBob;
	}
	
	clearscope TextureID GetScopeTexture() const
	{
		return TexMan.CheckForTexture(scopeTexture, TexMan.Type_Any);
	}
	
	override void Tick()
	{
		super.Tick();
		
		if (!owner || !owner.player || owner.health <= 0 || owner.player.ReadyWeapon != self)
		{
			if (cam)
				cam.Destroy();
		}
		
		bDrawScope = cam != null;
		
		if (!owner || !owner.player)
			return;
		
		double prevBob = owner.player.mo.curbob;
		weaponBob = owner.player.mo.BobWeapon(1);
		owner.player.mo.curbob = prevBob;
		
		Vector3 angles = (owner.angle, owner.pitch, owner.roll);
		if (!(angles ~== prevAngles))
		{
			double ac, as, pc, ps, rc, rs;
			ac = cos(angles.x);
			as = sin(angles.x);
			pc = cos(angles.y);
			ps = sin(angles.y);
			rc = cos(angles.z);
			rs = sin(angles.z);
				
			f = (ac*pc, as*pc, -ps);
			r = (-1*rs*ps*ac + -1*rc*-as, -1*rs*ps*as + -1*rc*ac, -1*rs*pc);
			u = (rc*ps*ac + -rs*-as, rc*ps*as + -rs*ac, rc*pc);
		}
		
		prevAngles = angles;
		
		if (!bDrawScope)
			return;
		
		Vector3 offset = f*forwardOffset + r*sideOffset + u*upOffset;
		let psp = owner.player.GetPSprite(PSP_WEAPON);
		double xOfs = psp.x;
		if (psp.bMirror)
			xOfs *= -1;
		offset += r*(weaponBob.x+xOfs)*swaySideMultiplier - u*(psp.y-WEAPONTOP+weaponBob.y)*swayUpMultiplier;
		
		cam.SetXYZ(level.Vec3Offset((owner.pos.xy,owner.player.viewz), offset));
		cam.angle = angles.x;
		cam.pitch = angles.y;
		cam.roll = angles.z;
	}
	
	action void A_Scope(bool doUnscope = true)
	{
		if (invoker.cam)
		{
			if (doUnscope)
				A_Unscope();
			
			return;
		}
		
		invoker.cam = ScopeCam(Spawn("ScopeCam"));
		if (invoker.cam)
			TexMan.SetCameraToTexture(invoker.cam, "SCAMTEX1", invoker.CameraFOV);
	}
	
	action void A_Unscope()
	{
		if (invoker.cam)
			invoker.cam.Destroy();
	}
	
	action void A_ChangeScopeZoom(double zoomMulti = 1)
	{
		if (zoomMulti ~== 0)
			return;
		
		invoker.CameraFOV = invoker.default.CameraFOV / zoomMulti;
	}
	
	action void A_ChangeScopeFoV(double fov = 0, bool relative = true)
	{
		if (relative)
			invoker.CameraFOV = invoker.default.CameraFOV - fov;
		else
			invoker.CameraFOV = fov;
	}
	
	action bool IsScoped()
	{
		return invoker.cam != null;
	}
	
	action double GetScopeZoom()
	{
		if (invoker.CameraFOV ~== 0)
			return invoker.default.CameraFOV;
		
		return invoker.default.CameraFOV / invoker.CameraFOV;
	}
	
	action double GetScopeFoV(bool relative = true)
	{
		if (relative)
			return invoker.default.CameraFOV - invoker.CameraFOV;
		
		return invoker.CameraFOV;
	}
}

class ScopeCam : Actor
{
	Default
	{
		FloatBobPhase 0;
		Height 0;
		Radius 0;
		
		+NOBLOCKMAP
		+NOSECTOR
		+SYNCHRONIZED
		+DONTBLAST
		+NOTONAUTOMAP
	}
	
	override void Tick() {}
}