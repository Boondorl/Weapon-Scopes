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
		
		CameraFOV 15;
		ScopedWeapon.RenderHeightOffset 32;
		ScopedWeapon.ScopeTexture "TROOA1";
	}
	
	States
	{
		Ready:
			CHGG A 1 A_WeaponReady(!(player.oldButtons & BT_ZOOM) ? WRF_ALLOWZOOM : 0);
			Loop;
			
		Zoom:
			CHGG A 1 A_Scope;
			Goto Ready;
			
		Deselect:
			TNT1 A 0 A_Unscope;
			CHGG A 1 A_Lower;
			Wait;
			
		Select:
			CHGG A 1 A_Raise;
			Loop;
			
		Fire:
			TNT1 A 0 {invoker.cameraFov += 2;}
			CHGG AB 4 A_FireCGun;
			CHGG B 0 A_ReFire;
			TNT1 A 0 {invoker.cameraFov = invoker.default.cameraFov;}
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