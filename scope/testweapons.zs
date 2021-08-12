class ScopedChaingun : ScopedWeapon replaces Chaingun
{
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
		ScopedWeapon.ScopeTexture "TROOA1";
		ScopedWeapon.SwaySideMultiplier 1;
		ScopedWeapon.SwayUpMultiplier 1;
	}
	
	States
	{
		Ready:
			CHGG A 1
			{
				int flags;
				if (IsScoped())
				{
					double zoom = GetScopeZoom();
					if (zoom < 3)
						flags |= WRF_ALLOWUSER1;
					if (zoom > 1)
						flags |= WRF_ALLOWUSER2;
				}
				
				if (!(player.oldButtons & BT_ZOOM))
					flags |= WRF_ALLOWZOOM;
				
				A_WeaponReady(flags);
			}
			Loop;
			
		Zoom:
			CHGG A 1
			{
				if (!IsScoped())
					A_ChangeScopeFoV(interpolate: false);
				
				A_Scope();
			}
			Goto Ready;
			
		User1:
			CHGG A 1
			{
				double zoom = GetScopeZoom();
				if (zoom < 3)
					A_ChangeScopeZoom(min(zoom+0.1,3));
			}
			Goto Ready;
			
		User2:
			CHGG A 1
			{
				double zoom = GetScopeZoom();
				if (zoom > 1)
					A_ChangeScopeZoom(max(zoom-0.1,1));
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
			CHGG AB 4 A_FireCGun;
			CHGG B 0 A_ReFire;
			Goto Ready;
			
		Flash:
			CHGF A 5 Bright A_Light1;
			Goto LightDone;
			CHGF B 5 Bright A_Light2;
			Goto LightDone;
			
		Spawn:
			MGUN A -1;
			Stop;
	}
}