/**
 * ---------------------------------------------------------------------
 * ModifyMoversMod 2019-01-10
 * ---------------------------------------------------------------------
 * A simple mutator which triggers and then disables movers at the
 * beginning of a map (well, kind of - see comment before ModifyPlayer).
 *
 * This mutator can also change the MoverEncroachType of movers, however
 * BTPlusPlus already includes such functionality.
 */
class ModifyMoversMod expands Mutator config(ModifyMoversMod);

/**
 * struct MI - MoverInfo
 *
 * This struct contains a map name and the tags of movers which the
 * user desires to trigger/disable or change to CrushWhenEncroach.
 *
 * An example from the config file:
 *
 *     MapName="CTF-BT-BlitzCastle",KeepOpen="Mover4,Mover4x",Crush=""
 *
 * This triggers and then disables the opening doors for BlitzCastle.
 */
struct MI {
	var config string MapName;
	var config string KeepOpen;
	var config string Crush;
};

var bool bInitialised, bMoversChecked;
var config MI MoverInfo[1024];

function PreBeginPlay() {
	if (bInitialised) {
		return;
	}

	Log("");
	Log("+----------------------------+");
	Log("| ModifyMoversMod 2019-01-10 |");
	Log("+----------------------------+");

	Level.Game.BaseMutator.AddMutator(self);
	bInitialised = true;
}

/**
 * This very dirty hack is used to trigger the movers.
 * CheckMovers() is called here as Movers require an
 * actor/pawn to trigger them.
 *
 * Using a dummy local PlayerPawn variable doesn't seem to work.
 */
function ModifyPlayer(Pawn Other) {

	if (!bMoversChecked && Other.IsA('PlayerPawn')) {
		CheckMovers(PlayerPawn(Other));

		// Prevent further checks.
		bMoversChecked = true;
	}

	if (NextMutator != none) {
		NextMutator.ModifyPlayer(Other);
	}
}

function CheckMovers(PlayerPawn P) {
	local string CurrentMap;
	local int    i;
	local Mover  M;

	// Get the current map name and check if this is in the config file.
	CurrentMap = Left(string(Level), InStr(string(Level), "."));

	// Begin checking the config file.
	for (i = 0; i < ArrayCount(MoverInfo); i++) {
		if (MoverInfo[i].MapName == CurrentMap) {

			/**
			 * To avoid false positives, add a delimiter to the end of the list and also to
			 * the end of each mover tag being checked.
			 *
			 * A false positive would be if the KeepOpen movers list is "Door" and there are
			 * multiple movers which have tags beginning with "Door".
			 *
			 * e.g. if there's a mover at the beginning of the map with a tag of "Door" and further
			 * on in the map there's a mover with a tag of "Door2", then InStr(KeepOpen, "Door")
			 * would match "Door2" and trigger it if was encountered first in the ForEach loop.
			 *
			 * Adding a delimiter (in this case a comma) prevents this as non-alphanumeric
			 * characters are prohibited in the Name data type.
			 */

			// Iterate through each mover in the map and check if it should be modified.
			foreach AllActors(class'Mover', M) {

				// Check if this mover is to be kept open permanently.
				if (
					MoverInfo[i].KeepOpen != "" &&
					InStr(MoverInfo[i].KeepOpen $ ",", string(M.Tag) $ ",") != -1
				) {

					Log("[ModifyMoversMod] Opening mover: " $ M $ "; Tag: \"" $ M.Tag $ "\"");

					// Set the mover to only be triggered once (now).
					M.bTriggerOnceOnly = true;

					switch (M.InitialState) {
						case 'BumpOpenTimed':
							M.HandleDoor(P);
						break;

						case 'StandOpenTimed':
							M.Attach(P);
						break;

						default:
							M.Trigger(P, P);
						break;
					}
				}

				// Check if this mover is to be set to crush when encroaching players.
				else if (
					MoverInfo[i].Crush != "" &&
					InStr(MoverInfo[i].Crush $ ",", string(M.Tag) $ ",") != -1
				) {
					Log("[ModifyMoversMod] Setting mover to crush: " $ M $ "; Tag: \"" $ M.Tag $ "\"");
					M.MoverEncroachType = ME_CrushWhenEncroach;
				}

			}

			// No need to keep iterating through the config file once the map is found.
			return;
		}
	}
}