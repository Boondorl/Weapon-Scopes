class ScopedChaingun : ScopedWeapon replaces Chaingun
{
	private Vector2 recoilOffset;
	private double recoilScale;
	private int recoilTics;
	private int recoilCounter;
	private bool inTilt;
	
	Default
	{
		Weapon.SlotNumber 4;
		Weapon.SelectionOrder 700;
		Weapon.AmmoUse 1;
		Weapon.AmmoGive 20;
		Weapon.AmmoType "Clip";
		Inventory.PickupMessage "$GOTCHAINGUN";
		Obituary "$OB_MPCHAINGUN";
		Tag "$TAG_CHAINGUN";
		
		// Scope properties
		CameraFOV 15;
		ScopedWeapon.RenderHeightOffset 32;
		ScopedWeapon.ScopeTexture "CROSSHAI";
		ScopedWeapon.SwaySideMultiplier 1;
		ScopedWeapon.SwayUpMultiplier 1;
	}
	
	States
	{
		Ready:
			CHGG A 1
			{
				int flags;
				bool scoped = IsScoped();
				if (scoped)
				{
					if (!(player.oldButtons & BT_RELOAD))
						flags |= WRF_ALLOWRELOAD;
					
					double zoom = GetScopeZoom();
					if (zoom < 3)
						flags |= WRF_ALLOWUSER1;
					if (zoom > 1)
						flags |= WRF_ALLOWUSER2;
				}
				
				if (!(player.oldButtons & BT_ZOOM))
					flags |= WRF_ALLOWZOOM;
				
				A_WeaponReady(flags);
				
				if (scoped)
					A_WeaponOffset(0, WEAPONTOP+frandom[Chaingun](-0.25,0.25), WOF_INTERPOLATE);
			}
			Loop;
			
		Zoom:
			CHGG A 1
			{
				if (!IsScoped())
					A_ChangeScopeFoV(interpolate: false);
				
				A_Scope();
				A_WeaponReady();
			}
			Goto Ready;
			
		User1:
			CHGG A 1
			{
				double zoom = GetScopeZoom();
				if (zoom < 3)
					A_ChangeScopeZoom(min(zoom+0.1,3));
				
				A_WeaponReady();
			}
			Goto Ready;
			
		User2:
			CHGG A 1
			{
				double zoom = GetScopeZoom();
				if (zoom > 1)
					A_ChangeScopeZoom(max(zoom-0.1,1));
				
				A_WeaponReady();
			}
			Goto Ready;
			
		Reload:
			CHGG A 1
			{
				invoker.inTilt = !invoker.inTilt;
				A_WeaponReady();
			}
			Goto Ready;
			
		Deselect:
			TNT1 A 0 A_Unscope;
			CHGG A 1 A_Lower;
			Wait;
			
		Select:
			CHGG A 1 A_Raise;
			Loop;
			
		Fire:
			CHGG AB 3 A_FireNewCGun;
			CHGG B 0 A_ReFire;
			Goto Ready;
			
		Flash:
			CHGF A 4 Bright A_Light1;
			Goto LightDone;
			CHGF B 4 Bright A_Light2;
			Goto LightDone;
			
		Spawn:
			MGUN A -1;
			Stop;
	}
	
	action void A_FireNewCGun()
	{
		A_FireCGun();
		if (IsScoped())
		{
			double r = player.GetPSprite(PSP_WEAPON).rotation;
			invoker.recoilOffset = RotateVector((frandom[Chaingun](-1,3), frandom[Chaingun](2,6)), r);
			invoker.recoilScale = frandom[Chaingun](1.05,1.1);
			invoker.recoilTics = player.GetPSprite(PSP_WEAPON).tics;
			invoker.recoilCounter = 0;
		}
	}
	
	override void OwnerDied()
	{
		recoilTics = 0;
	}
	
	override void DoEffect()
	{
		if (!owner || !owner.player || owner.player.ReadyWeapon != self)
		{
			recoilTics = 0;
			return;
		}
		
		if (IsScoped())
		{
			bobStyle = Bob_InverseSmooth;
			bobRangeX = 0.2;
			bobRangeY = 0.1;
			bobSpeed = 1.5;
		}
		else
		{
			bobStyle = default.bobStyle;
			bobRangeX = default.bobRangeX;
			bobRangeY = default.bobRangeY;
			bobSpeed = default.bobSpeed;
		}
		
		let psp = owner.player.GetPSprite(PSP_WEAPON);
		psp.bInterpolate = true;
		psp.VAlign = PSPA_BOTTOM;
		psp.HAlign = PSPA_CENTER;
		
		if (inTilt)
		{
			if (psp.rotation < 5)
				++psp.rotation;
			
			psp.x = psp.rotation*2;
			Vector2 rot = RotateVector((default.renderWidthOffset, default.renderHeightOffset), psp.rotation*5);
			renderWidthOffset = rot.x;
			renderHeightOffset = rot.y;
		}
		else
		{
			if (psp.rotation > 0)
				--psp.rotation;
			
			psp.x = psp.rotation*2;
			Vector2 rot = RotateVector((default.renderWidthOffset, default.renderHeightOffset), psp.rotation*5);
			renderWidthOffset = rot.x;
			renderHeightOffset = rot.y;
		}
		
		if (recoilTics <= 0)
			return;
		
		double mod = (recoilTics - recoilCounter++) / recoilTics;
		if (recoilOffset.x)
			psp.x += recoilOffset.x*mod;
		if (recoilOffset.y)
			psp.y = WEAPONTOP - recoilOffset.y*mod;
		if (recoilScale)
		{
			double diff = 1 + (recoilScale - 1)*mod;
			psp.scale = (diff, diff);
			let f = owner.player.FindPSprite(PSP_FLASH);
			if (f)
			{
				f.rotation = psp.rotation;
				f.scale = (diff, diff);
				if (recoilCounter > 1)
					f.bInterpolate = true;
			}
		}
		
		if (recoilCounter >= recoilTics)
			recoilTics = 0;
	}
}