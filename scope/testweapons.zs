class ScopedChaingun : ScopedWeapon replaces Chaingun
{
	// Variables for handling recoil
	private Vector2 recoilOffset;
	private double recoilScale;
	private int recoilTics;
	private int recoilCounter;
	
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
		
		// Scope-specific properties
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
					// If scoped, allow the ability to change the zoom level
					double zoom = GetScopeZoom();
					if (zoom < 3)
						flags |= WRF_ALLOWUSER1;
					if (zoom > 1)
						flags |= WRF_ALLOWUSER2;
				}
				
				if (!(player.oldButtons & BT_ZOOM))
					flags |= WRF_ALLOWZOOM;
				
				A_WeaponReady(flags);
				A_OverlayScale(PSP_WEAPON, 1, 0, WOF_INTERPOLATE);
				
				// Shake a little when scoped as well
				if (scoped)
					A_WeaponOffset(frandom[Chaingun](-0.25,0.25), WEAPONTOP-frandom[Chaingun](-0.25,0.25), WOF_INTERPOLATE);
			}
			Loop;
			
		Zoom:
			CHGG A 1
			{
				if (!IsScoped())
					A_ChangeScopeFoV(interpolate: false); // Reset the FoV when bringing up the scope
				
				A_Scope();
				A_WeaponReady();
			}
			Goto Ready;
			
		// Zoom in
		User1:
			CHGG A 1
			{
				double zoom = GetScopeZoom();
				if (zoom < 3)
					A_ChangeScopeZoom(min(zoom+0.1,3));
				
				A_WeaponReady();
			}
			Goto Ready;
		
		// Zoom out
		User2:
			CHGG A 1
			{
				double zoom = GetScopeZoom();
				if (zoom > 1)
					A_ChangeScopeZoom(max(zoom-0.1,1));
				
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
			CHGG A 1 A_FireNewCGun;
			CHGG AA 1 A_WeaponRecoil;
			CHGG B 1 A_FireNewCGun;
			CHGG BB 1 A_WeaponRecoil;
			CHGG B 0 A_ReFire;
			Goto Ready;
			
		Flash:
			CHGF A 0 A_Light1;
			CHGF AAA 1 Bright A_WeaponRecoil(OverlayID());
			Goto LightDone;
			CHGF B 0 A_Light2;
			CHGF BBB 1 Bright A_WeaponRecoil(OverlayID());
			Goto LightDone;
			
		Spawn:
			MGUN A -1;
			Stop;
	}
	
	// Set recoil properties
	action void A_FireNewCGun()
	{
		invoker.recoilOffset = (frandom[Chaingun](-0.5,1.5), frandom[Chaingun](2,4));
		invoker.recoilScale = frandom[Chaingun](1.025,1.05);
		invoker.recoilTics = 3;
		invoker.recoilCounter = 0;
		
		A_FireCGun();
		A_WeaponRecoil();
	}
	
	// Handles the weapon offsetting and scaling from recoil
	action void A_WeaponRecoil(int id = PSP_WEAPON)
	{
		if (invoker.recoilTics <= 0 || invoker.recoilCounter >= invoker.recoilTics)
			return;
		
		A_OverlayPivotAlign(id, PSPA_CENTER, PSPA_BOTTOM);
		
		double ratio = double(invoker.recoilTics - invoker.recoilCounter) / invoker.recoilTics;
		A_OverlayScale(id, 1 + (invoker.recoilScale-1)*ratio, 0, WOF_INTERPOLATE);
		
		if (id == PSP_WEAPON)
		{
			++invoker.recoilCounter;
			
			Vector2 offset = invoker.recoilOffset * ratio;
			A_OverlayOffset(id, offset.x, WEAPONTOP - offset.y, WOF_INTERPOLATE); 
		}
	}
}