//version "2.4"

class ScopeHandler : EventHandler
{
	// Interpolation data
	private ui Vector2 oldScale;
	private ui double oldRotation;
	private ui Vector2 oldPos;
	private ui double oldFoV;
	
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
			
		//psp.rotation += 2;
		psp.bInterpolate = true;
		psp.pivot = (0.5,0.5);
		psp.bPivotPercent = true;
		psp.HAlign = PSPA_LEFT;
		psp.VAlign = PSPA_TOP;
		//psp.bFlip = true;
		//psp.bMirror = true;
	}
	// END DEBUG
	
	override void UITick()
	{
		let weap = ScopedWeapon(players[consoleplayer].ReadyWeapon);
		if (!weap)
		{
			oldRotation = 0;
			oldScale = (1,1);
			oldFoV = 0;
			oldPos = (0,WEAPONBOTTOM);
			return;
		}
		
		let psp = players[consoleplayer].GetPSprite(PSP_WEAPON);
		oldRotation = psp.rotation;
		oldScale = psp.scale;
		oldPos = (psp.x,psp.y) + weap.GetWeaponBobOffset();
		oldFoV = weap.CameraFOV;
	}
	
	override void RenderUnderlay(RenderEvent e)
	{
		let weap = ScopedWeapon(players[consoleplayer].ReadyWeapon);
		if (!weap || automapactive || !weap.ShouldDrawScope())
			return;
		
		if (!circle)
			circle = CreateCircle();
		if (!lens.IsValid())
			lens = TexMan.CheckForTexture("SCAMTEX1", TexMan.Type_Any);
		
		if (oldFoV != weap.CameraFOV)
			TexMan.SetCameraToTexture(weap.GetCamera(), "SCAMTEX1", LerpFloat(weap.GetPrevFoV(), weap.CameraFOV, e.fracTic));
		
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
		bool interpolate = psp.interpolateTic || psp.bInterpolate;
		
		Vector2 bob = weap.GetWeaponBobOffset();
		Vector2 pos = (psp.x,psp.y) + bob;
		Vector2 realPos;
		if (psp.oldx != psp.x || interpolate || bob.x)
			realPos.x = LerpFloat(oldPos.x, pos.x, e.fracTic);
		else
			realPos.x = pos.x;
		if (psp.bMirror)
			realPos.x *= -1;
		
		if (psp.oldy != psp.y || interpolate || bob.y)
			realPos.y = LerpFloat(oldPos.y, pos.y, e.fracTic);
		else
			realPos.y = pos.y;
		if (screenblocks >= 11)
			realPos.y += weap.YAdjust;
		
		Vector2 scopeScale = interpolate ? Lerp(oldScale, psp.scale, e.fracTic) : psp.scale;
		double scopeAngle = interpolate ? -LerpFloat(oldRotation, psp.rotation, e.fracTic) : -psp.rotation;
		
		Vector2 scopePos = (wOfs + w/2 + realPos.x*scale.x, hOfs + h/2 + realPos.y*scale.y);
		Vector2 prevOfs = weap.GetPrevRenderOffset();
		Vector2 scopeOfs = (LerpFloat(prevOfs.x, weap.renderWidthOffset, e.fracTic)*scale.x, -LerpFloat(prevOfs.y, weap.renderHeightOffset, e.fracTic)*scale.y);
		if (psp.bMirror)
			scopeOfs.x *= -1;
		Vector2 scopeSize = TexMan.GetScaledSize(lens)*LerpFloat(weap.GetPrevScale(), weap.scopeScale, e.fracTic) / 2 * multi;
		
		// Calculate the correct anchor point for scaling and rotating
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
		Vector2 anchorOffset = (scopeSize.x*anchor.x, scopeSize.y*anchor.y);
		scopePos -= anchorOffset;
		
		scopeSize.x *= scopeScale.x;
		scopeSize.y *= scopeScale.y;
		scopePos += scopeOfs;
		
		// Make sure it can't draw outside of the view port
		int cx, cy, cw, ch;
		[cx, cy, cw, ch] = Screen.GetClipRect();
		Screen.SetClipRect(wOfs, hOfs, w, h);
		
		DrawScope(lens, false, circle, scopePos, scopeSize, scopeAngle, anchor: anchor, -scopeAngle);
		let id = weap.GetScopeTextureID();
		if (id.IsValid())
			DrawScope(id, true, circle, scopePos, scopeSize, scopeAngle, weap.ScopeRenderStyle(), psp.alpha, anchor);
		
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
	
	ui void DrawScope(TextureID id, bool anim, Shape2D shape, Vector2 pos, Vector2 size, double ang = 0, int renderStyle = STYLE_Normal, double alpha = 1, Vector2 anchor = (0,0), double anchorAng = 0)
    {
		if (!shape)
			return;
		
		let transform = new("Shape2DTransform");
		transform.Rotate(anchorAng);
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
	// Interpolation data
	private Vector2 prevRenderOffset;
	private double prevFoV;
	private double prevScale;
	
	private Vector2 pro;
	private double pf;
	private double ps;
	
	private bool bDrawScope;
	private ScopeCam cam;
	private Vector2 weaponBob;
	private Vector3 f, r, u;
	private Vector3 prevAngles;
	private int prevStyle;
	
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
	}
	
	clearscope Vector2 GetPrevRenderOffset() const
	{
		return pro;
	}
	
	clearscope double GetPrevFoV() const
	{
		return pf;
	}
	
	clearscope double GetPrevScale() const
	{
		return ps;
	}
	
	clearscope int ScopeRenderStyle() const
	{
		if (prevStyle != STYLE_None)
			return prevStyle;
		
		if (!owner)
			return GetRenderStyle();
		
		return owner.GetRenderStyle();
	}
	
	clearscope bool ShouldDrawScope() const
	{
		return bDrawScope;
	}
	
	clearscope ScopeCam GetCamera() const
	{
		return cam;
	}
	
	clearscope Vector2 GetWeaponBobOffset() const
	{
		return weaponBob;
	}
	
	clearscope TextureID GetScopeTextureID() const
	{
		return TexMan.CheckForTexture(scopeTexture, TexMan.Type_Any);
	}
	
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		
		ClearScopeInterpolation();
	}
	
	override void AlterWeaponSprite(VisStyle vis, out int changed)
	{
		if (prevStyle != STYLE_None)
			vis.RenderStyle = prevStyle;
	}
	
	override void Tick()
	{
		pro = prevRenderOffset;
		pf = prevFoV;
		ps = prevScale;
		
		ClearScopeInterpolation();
		
		super.Tick();
		
		if (!owner || !owner.player || owner.health <= 0 || owner.player.ReadyWeapon != self)
		{
			if (cam)
				cam.Destroy();
		}
		
		bDrawScope = cam != null && (!owner || !owner.player || !(owner.player.cheats & CF_CHASECAM));
		
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
		{
			if (prevStyle != STYLE_None)
			{
				owner.A_SetRenderStyle(owner.alpha, prevStyle);
				prevStyle = STYLE_None;
			}
			
			return;
		}
		
		if (owner.PlayerNumber() == consoleplayer)
		{
			int style = owner.GetRenderStyle();
			if (style != STYLE_None)
			{
				prevStyle = style;
				owner.A_SetRenderStyle(owner.alpha, STYLE_None);
			}
		}
		
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
	
	action void A_ChangeScopeZoom(double zoomMulti = 1, bool interpolate = true)
	{
		if (zoomMulti ~== 0)
			return;
		
		invoker.CameraFOV = invoker.default.CameraFOV / zoomMulti;
		
		if (!interpolate)
			ClearScopeInterpolation(false, true, false);
	}
	
	action void A_ChangeScopeFoV(double fov = 0, bool relative = true, bool interpolate = true)
	{
		if (relative)
			invoker.CameraFOV = invoker.default.CameraFOV - fov;
		else
			invoker.CameraFOV = fov;
		
		if (!interpolate)
			ClearScopeInterpolation(false, true, false);
	}
	
	action void A_ScopeSway(double x = 0, double y = 0, bool relative = true)
	{
		if (relative)
		{
			invoker.swaySideMultiplier += x;
			invoker.swayUpMultiplier += y;
		}
		else
		{
			invoker.swaySideMultiplier = x;
			invoker.swayUpMultiplier = y;
		}
	}
	
	action void A_ScopeOffset(double f = 0, double s = 0, double u = 0, bool relative = true)
	{
		if (relative)
		{
			invoker.forwardOffset += f;
			invoker.sideOffset += s;
			invoker.upOffset += u;
		}
		else
		{
			invoker.forwardOffset = f;
			invoker.sideOffset = s;
			invoker.upOffset = u;
		}
	}
	
	action void A_ScopeRenderOffset(double x = 0, double y = 0, bool relative = true, bool interpolate = true)
	{
		if (relative)
		{
			invoker.RenderWidthOffset += x;
			invoker.RenderHeightOffset += y;
		}
		else
		{
			invoker.RenderWidthOffset = x;
			invoker.RenderHeightOffset = y;
		}
		
		if (!interpolate)
			ClearScopeInterpolation(true, false, false);
	}
	
	action void A_SetScopeTexture(string name)
	{
		invoker.scopeTexture = name;
	}
	
	action void A_SetScopeScale(double s, bool relative = true, bool interpolate = true)
	{
		if (relative)
			invoker.scopeScale += s;
		else
			invoker.scopeScale = s;
		
		if (!interpolate)
			ClearScopeInterpolation(false, false);
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
	
	action double GetScopeForwardOffset()
	{
		return invoker.forwardOffset;
	}
	
	action double GetScopeSideOffset()
	{
		return invoker.sideOffset;
	}
	
	action double GetScopeUpOffset()
	{
		return invoker.upOffset;
	}
	
	action double GetScopeWidthOffset()
	{
		return invoker.RenderWidthOffset;
	}
	
	action double GetScopeHeightOffset()
	{
		return invoker.RenderHeightOffset;
	}
	
	action double GetScopeScale()
	{
		return invoker.scopeScale;
	}
	
	action string GetScopeTexture()
	{
		return invoker.scopeTexture;
	}
	
	action void ClearScopeInterpolation(bool rendering = true, bool fov = true, bool scale = true)
	{
		if (rendering)
			invoker.prevRenderOffset = (invoker.RenderWidthOffset, invoker.RenderHeightOffset);
		if (fov)
			invoker.prevFoV = invoker.CameraFOV;
		if (scale)
			invoker.prevScale = invoker.scopeScale;
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