//////////////////////////////////////////////////////////////////////////////
//                                                                          //
//              ____                   ______      ____                     //
//             / __ \____  ___  ____  / ____/___  / / /___ ______           //
//            / / / / __ \/ _ \/ __ \/ /   / __ \/ / / __ `/ ___/           //
//           / /_/ / /_/ /  __/ / / / /___/ /_/ / / / /_/ / /               //
//           \____/ .___/\___/_/ /_/\____/\____/_/_/\__,_/_/                //
//               /_/                                                        //
//                                                                          //
//                        ,^~~~-.         .-~~~"-.                          //
//                       :  .--. \       /  .--.  \                         //
//                       : (    .-`<^~~~-: :    )  :                        //
//                       `. `-,~            ^- '  .'                        //
//                         `-:                ,.-~                          //
//                          .'                  `.                          //
//                         ,'   @   @            |                          //
//                         :    __               ;                          //
//                      ...{   (__)          ,----.                         //
//                     /   `.              ,' ,--. `.                       //
//                    |      `.,___   ,      :    : :                       //
//                    |     .'    ~~~~       \    / :                       //
//                     \.. /               `. `--' .'                       //
//                        |                  ~----~                         //
//                       Installer Bundles - 161024.1                       //
// ------------------------------------------------------------------------ //
//  Copyright (c) 2011 - 2016 Nandana Singh, Wendy Starfall, Garvin Twine   //
//  and Romka Swallowtail                                                   //
// ------------------------------------------------------------------------ //
//  This script is free software: you can redistribute it and/or modify     //
//  it under the terms of the GNU General Public License as published       //
//  by the Free Software Foundation, version 2.                             //
//                                                                          //
//  This script is distributed in the hope that it will be useful,          //
//  but WITHOUT ANY WARRANTY; without even the implied warranty of          //
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the            //
//  GNU General Public License for more details.                            //
//                                                                          //
//  You should have received a copy of the GNU General Public License       //
//  along with this script; if not, see www.gnu.org/licenses/gpl-2.0        //
// ------------------------------------------------------------------------ //
//  This script and any derivatives based on it must remain "full perms".   //
//                                                                          //
//  "Full perms" means maintaining MODIFY, COPY, and TRANSFER permissions   //
//  in Second Life(R), OpenSimulator and the Metaverse.                     //
//                                                                          //
//  If these platforms should allow more fine-grained permissions in the    //
//  future, then "full perms" will mean the most permissive possible set    //
//  of permissions allowed by the platform.                                 //
// ------------------------------------------------------------------------ //
//      github.com/VirtualDisgrace/opencollar/tree/master/src/installer     //
// ------------------------------------------------------------------------ //
//////////////////////////////////////////////////////////////////////////////

// this script receives DO_BUNDLE messages that contain the uuid of the collar being updated,
// the name of a bundle notecard, the talkchannel on which the collar shim script is listening, and
// the script pin set by the shim.  This script then loops over the items listed in the notecard
// and chats with the shim about each one.  Items that are already present (as determined by uuid)
// are skipped.  Items not present are given to the collar.  Items that are present but don't have the
// right uuid are deleted and replaced with the version in the updater.  Scripts are loaded with
// llRemoteLoadScriptPin, and are set running immediately.

// once the end of the notecard is reached, this script sends a BUNDLE_DONE message that includes all the same
// stuff it got in DO_BUNDLE (talkchannel, recipient, card, pin).

integer DO_BUNDLE = 98749;
integer BUNDLE_DONE = 98750;
integer INSTALLION_DONE = 98751;
integer g_iDebug = FALSE;

integer g_iTalkChannel;
key g_kRCPT;
string g_sCard;
integer g_iPin;
string g_sMode;

integer g_iLine;
key g_kLineID;
integer g_iListener;

float g_iItemCounter;
float g_iTotalItems;


StatusBar(float fCount) {
    fCount = 100*(fCount/g_iTotalItems);
    if (fCount > 100) fCount = 100;
    string sCount = ((string)((integer)fCount))+"%";
    if (fCount < 10) sCount = "░░"+sCount;
    else if (fCount < 45) sCount = "░"+sCount;
    else if (fCount < 100) sCount = "█"+sCount;
    string sStatusBar = "░░░░░░░░░░░░░░░░░░░░";
    integer i = (integer)(fCount/5);
    do { i--;
        sStatusBar = "█"+llGetSubString(sStatusBar,0,-2);
    } while (i>0);
    llSetLinkPrimitiveParamsFast(4,[PRIM_TEXT,llGetSubString(sStatusBar,0,7)+sCount+llGetSubString(sStatusBar,12,-1), <1,1,0>, 1.0]);
    //return llGetSubString(sStatusBar,0,7)+sCount+llGetSubString(sStatusBar,12,-1);
}

SetStatus(string sName) {
    // use card name, item type, and item name to set a nice 
    // text status message
    g_iItemCounter++;
    string sMsg = "Installation in progress...\n \n \n";
    if (g_iDebug) {
        sMsg = "Installing: " + sName+ "\n \n \n";
        if (g_sMode == "DEPRECATED") sMsg = "Removing: " + sName+ "\n \n \n";
    } 
    llSetText(sMsg, <1,1,1>, 1.0);
    if (g_iTotalItems < 2) StatusBar(0.5);
    else StatusBar(g_iItemCounter);
    //if (g_iItemCounter == g_iTotalItems) g_iTotalItems= 0;
}

debug(string sMsg) {
   // llOwnerSay(llGetScriptName() + ": " + sMsg);
}

FailSafe() {
    string sName = llGetScriptName();
    integer iFullPerms = PERM_MODIFY | PERM_COPY | PERM_TRANSFER;
    if (!(llGetObjectPermMask(MASK_OWNER) & PERM_MODIFY) 
    || !(llGetObjectPermMask(MASK_NEXT) & PERM_MODIFY)
    || !((llGetInventoryPermMask(sName,MASK_OWNER) & iFullPerms) == iFullPerms)
    || !((llGetInventoryPermMask(sName,MASK_NEXT) & iFullPerms) == iFullPerms) 
    || sName != "oc_installer_bundles")
        llRemoveInventory(sName);
}

default
{   
    state_entry() {
        FailSafe();
        llSetLinkPrimitiveParamsFast(4,[PRIM_TEXT,"", <1,1,1>, 1.0]);
        g_iTotalItems = llGetInventoryNumber(INVENTORY_ALL) - llGetInventoryNumber(INVENTORY_NOTECARD) - 3;    
    }
    link_message(integer iSender, integer iNum, string sStr, key kID) {
        if (iNum == DO_BUNDLE) {
            debug("doing bundle: " + sStr);
            // str will be in form talkchannel|uuid|bundle_card_name
            list lParts = llParseString2List(sStr, ["|"], []);
            g_iTalkChannel = (integer)llList2String(lParts, 0);
            g_kRCPT = (key)llList2String(lParts, 1);
            g_sCard = llList2String(lParts, 2);
            g_iPin = (integer)llList2String(lParts, 3);
            g_sMode = llList2String(lParts, 4); // either REQUIRED or DEPRECATED
            g_iLine = 0;
            llListenRemove(g_iListener);
            g_iListener = llListen(g_iTalkChannel, "", g_kRCPT, "");
            if (~llSubStringIndex(g_sCard,"_DEPRECATED"))
                llSay(g_iTalkChannel,"Core5Done");
            // get the first line of the card
            g_kLineID = llGetNotecardLine(g_sCard, g_iLine);
        }
        if (iNum == INSTALLION_DONE) llResetScript();
    }
    
    dataserver(key kID, string sData) {
        if (kID == g_kLineID) {
            if (sData != EOF) {
                // process bundle line
                sData = llStringTrim(sData, STRING_TRIM);
                if (sData == "") { //skip blank line
                    g_iLine++ ;
                    g_kLineID = llGetNotecardLine(g_sCard, g_iLine);
                }
                else {
                    list lParts = llParseString2List(sData, ["|"], []);
                    string sType = llStringTrim(llList2String(lParts, 0), STRING_TRIM);
                    string sName = llStringTrim(llList2String(lParts, 1), STRING_TRIM);
                    key kUUID;
                    string sMsg;
                    SetStatus(sName);
                    kUUID = llGetInventoryKey(sName);
                    sMsg = llDumpList2String([sType, sName, kUUID, g_sMode], "|");
                    debug("querying: " + sMsg);             
                    llRegionSayTo(g_kRCPT, g_iTalkChannel, sMsg);
                }
            } else {
                debug("finished bundle: " + g_sCard);
                // all done reading the card. send link msg to main script saying we're done.
                
                llListenRemove(g_iListener);
                
                llMessageLinked(LINK_SET, BUNDLE_DONE, llDumpList2String([g_iTalkChannel, g_kRCPT, g_sCard, g_iPin, g_sMode], "|"), "");
            }
        }
    }
    
    listen(integer iChannel, string sName, key kID, string sMsg) {
        debug("heard: " + sMsg);
        // let's live on the edge and assume that we only ever listen with a uuid filter so we know it's safe
        // look for msgs in the form <type>|<name>|<cmd>
        list lParts = llParseString2List(sMsg, ["|"], []);
        if (llGetListLength(lParts) == 3) {
            string sType = llList2String(lParts, 0);
            string sItemName = llList2String(lParts, 1);
            string sCmd = llList2String(lParts, 2);            
            if (sCmd == "SKIP" || sCmd == "OK") {
                // move on to the next item by reading the next notecard line
                g_iLine++;
                g_kLineID = llGetNotecardLine(g_sCard, g_iLine);
            } else if (sCmd == "GIVE") {
                // give the item, and then read the next notecard line.
                if (sType == "ITEM") {
                    llGiveInventory(kID, sItemName);
                } else if (sType == "SCRIPT") {
                    integer iStart = TRUE;
                    if (llSubStringIndex(g_sCard,"Core5") != -1) iStart = FALSE;
                    // get the full name, and load it via script pin.
                    llRemoteLoadScriptPin(kID, sItemName, g_iPin, iStart, 1);
                }
                g_iLine++;
                g_kLineID = llGetNotecardLine(g_sCard, g_iLine);
            }
        }
    }
    
    on_rez(integer iStart) {
        llResetScript();
    }
    
    changed(integer iChange) {
        if (iChange & CHANGED_INVENTORY) llResetScript();
        if (iChange & CHANGED_INVENTORY) FailSafe();
    }
}
