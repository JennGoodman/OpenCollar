/*
    This file is a part of OpenCollar.
    Copyright ©2020

    : Contributors :

    Aria (Tashia Redrose)
        *May 2020       -       Created new Integrated relay

    Kitty Mapholisto (sweetdangerkitty)
        *June 202       -       Reorganization
        
    et al.

    Licensed under the GPLv2. See LICENSE for full details.
    https://github.com/OpenCollarTeam/OpenCollar

    Disabled Constants
    ----------------------------------
    integer CMD_ZERO            = 0;
    integer CMD_GROUP           = 502;
    integer CMD_EVERYONE        = 504;
    integer CMD_RLV_RELAY       = 507;
    integer CMD_SAFEWORD        = 510;
    integer CMD_RELAY_SAFEWORD  = 511;
    integer REBOOT              = -1000;
    integer LM_SETTING_EMPTY    = 2004; // sent when a token has no value
    integer MENUNAME_REMOVE     = 3003;
    integer RLV_CMD             = 6000;
    integer RLV_REFRESH         = 6001; // RLV plugins should reinstate their restrictions upon receiving this message.
    integer RLV_OFF             = 6100; // send to inform plugins that RLV is disabled now, no message or key needed
    integer RLV_ON              = 6101; // send to inform plugins that RLV is enabled now, no message or key needed
    integer DIALOG_TIMEOUT      = -9002;
    string  ALL                 = "ALL";
*/

// MESSAGE MAP
integer CMD_OWNER           = 500;
integer CMD_TRUSTED         = 501;
integer CMD_WEARER          = 503;

integer NOTIFY              = 1002;

integer LM_SETTING_SAVE     = 2000; // scripts send messages on this channel to have settings saved. str must be in form of "token=value"
integer LM_SETTING_REQUEST  = 2001; // when startup, scripts send requests for settings on this channel
integer LM_SETTING_RESPONSE = 2002; // the settings script sends responses on this channel
integer LM_SETTING_DELETE   = 2003; // delete token from settings

integer MENUNAME_REQUEST    = 3000;
integer MENUNAME_RESPONSE   = 3001;

integer RLV_RELAY_CHANNEL   = -1812221819;
integer RELAY_LISTENER;

integer DIALOG              = -9000;
integer DIALOG_RESPONSE     = -9001;

string  UPMENU              = "BACK";

integer MODE_ASK            = 1;
integer MODE_AUTO           = 2;

// Globals
string  g_sParentMenu       = "RLV";
string  g_sSubMenu          = "Relay";

integer g_iLocked           = FALSE;
integer g_iMode             = 0;
integer g_iMenuStride;
integer g_iResitStatus;

list    g_lMenuIDs;
list    g_lOwner;
list    g_lTrust;
list    g_lBlock;
list    g_lRestrictions;
list    g_lBlacklist;

key     g_kWearer;
key     g_kForcesitter;
key     g_kSitID;
key     g_kSource;

integer DEBUG               = TRUE;

doRelease() {
        
    llRegionSayTo(g_kSource, RLV_RELAY_CHANNEL, "release," + (string) g_kSource + ",!release,ok");
        
    integer index;
    integer length = llGetListLength(g_lRestrictions);
    while (index<length) {
        // Release restrictions
        string stripped = "@clear=" + llList2String(g_lRestrictions, index++);
        llOwnerSay(stripped);
    }
    g_kSource = NULL_KEY;
    g_lRestrictions = [];
}

default {
    state_entry() {

        g_kWearer = llGetOwner();
        llMessageLinked(LINK_SET, LM_SETTING_REQUEST, "global_locked", "");
    }

    on_rez( integer number ) { 

        if (llGetOwner() != g_kWearer) llResetScript();
    
        if (g_kSource) {
            
            g_iResitStatus = 0;
            
            llOwnerSay("@detach=n"); // no escaping before we are sure the former source really is not active anymore
            llRegionSayTo(g_kSource, RLV_RELAY_CHANNEL, "ping," + (string) g_kSource + ",ping,ping");
            
            llSetTimerEvent(30);
        }
    }

    timer() {
        
        if (g_iResitStatus == 1) {
            g_iResitStatus++;
            llSetTimerEvent(15);
            llOwnerSay("@sit:" + (string) g_kSitID + "=force");

        } else if (g_iResitStatus == 2) {
            llSetTimerEvent(0);
            llOwnerSay("@" + llDumpList2String(g_lRestrictions, "=n,") + "=n");

        } else doRelease();
    }
    link_message( integer iSender, integer iNum, string sStr, key kID ) {
        
        if (iNum >= CMD_OWNER && iNum <= CMD_WEARER) {

            if (iNum < CMD_OWNER || iNum > CMD_WEARER) return;

            if (llSubStringIndex(sStr, llToLower(g_sSubMenu)) && sStr != "menu " + g_sSubMenu) return;

            if (iNum == CMD_OWNER && sStr == "runaway") {
                g_lOwner = g_lTrust = g_lBlock = [];
                return;
            }
            if (sStr==g_sSubMenu || sStr == "menu " + g_sSubMenu) {

                string sPrompt = "\n[Relay App]";
                list lButtons = [llList2String(["⬜","⬛"], g_iMode == 0) + " OFF", llList2String(["⬜","⬛"], g_iMode == MODE_ASK) + " Ask", llList2String(["⬜","⬛"], g_iMode == MODE_AUTO) + " Auto"];
            
                key kMenuID = llGenerateKey();
                llMessageLinked(LINK_SET, DIALOG, (string)kID + "|" + sPrompt + "|0|" + llDumpList2String(lButtons, "`") + "|UPMENU|" + (string)iNum, kMenuID);
            
                integer iIndex = llListFindList(g_lMenuIDs, [kID]);
                if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, "Menu~Main"], iIndex, iIndex + g_iMenuStride - 1);
                else g_lMenuIDs += [kID, kMenuID, "Menu~Main"];
            }

        } else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu) {
            llMessageLinked(iSender, MENUNAME_RESPONSE, g_sParentMenu + "|" +  g_sSubMenu,"");

        } else if (iNum == DIALOG_RESPONSE) {

            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);

            if (iMenuIndex != -1) {

                string sMenu = llList2String(g_lMenuIDs, iMenuIndex + 1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex-1, iMenuIndex-2 + g_iMenuStride);

                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = llList2Key(lMenuParams, 0);
                string sMsg = llList2String(lMenuParams, 1);
                integer iAuth = llList2Integer(lMenuParams, 3);
                
                if (sMenu == "Menu~Main") {

                    if (sMsg == UPMENU) llMessageLinked(LINK_SET, iAuth, "menu " + g_sParentMenu, kAv);

                    else if (sMsg == llList2String(["⬜","⬛"], g_iMode == 0 + " OFF")) {

                        if (g_iMode == 0) {
                            llMessageLinked(LINK_SET, NOTIFY, "0The relay is already off", kAv);
                            
                        } else {
                            g_iMode = 0;
                            llMessageLinked(LINK_SET, NOTIFY, "0The relay has been turned off", kAv);
                        }
                        llMessageLinked(LINK_SET, LM_SETTING_SAVE, "relay_mode=" + (string) g_iMode, "");

                    } else if (sMsg == llList2String(["⬜","⬛"], g_iMode == MODE_ASK) + " Ask") {

                        if (g_iMode == MODE_ASK) {
                            llMessageLinked(LINK_SET, NOTIFY, "0The relay is already set to ask", kAv);

                        } else {
                            g_iMode = MODE_ASK;
                            llMessageLinked(LINK_SET, NOTIFY, "0The relay has been set to ask\n\n**Warning: Ask mode is not yet implemented and will be treated as fully automatic in this experimental build", kAv);
                        }
                        llMessageLinked(LINK_SET, LM_SETTING_SAVE, "relay_mode=" + (string) g_iMode, "");

                    } else if (sMsg == llList2String(["⬜","⬛"], g_iMode == MODE_AUTO) + " Auto") {

                        if (g_iMode == MODE_AUTO) {
                            llMessageLinked(LINK_SET, NOTIFY, "0The relay is already set to auto", kAv);

                        }else{
                            g_iMode = MODE_AUTO;
                            llMessageLinked(LINK_SET, NOTIFY, "0The relay is now set to auto", kAv);
                        }
                        llMessageLinked(LINK_SET, LM_SETTING_SAVE, "relay_mode=" + (string)g_iMode, "");
                    }
                }
            }
        } else if (iNum == LM_SETTING_RESPONSE) {

            // Detect Settings
            list lSettings = llParseString2List(sStr, ["_","="],[]);

            if (llList2String(lSettings,0) == "global") {
                if (llList2String(lSettings, 1) == "locked")
                    g_iLocked = llList2Integer(lSettings, 2);

            } else if (llList2String(lSettings, 0) == "relay") {

                if (llList2String(lSettings, 1) == "mode") {

                    if ((g_iMode = llList2Integer(lSettings,2)) == 0) {
                        llListenRemove(RELAY_LISTENER);
                        doRelease();

                    } else RELAY_LISTENER = llListen(RLV_RELAY_CHANNEL, "", NULL_KEY, "");
                }
            }
        } else if (iNum == LM_SETTING_DELETE) {

            // This is recieved back from settings when a setting is deleted
            list lSettings = llParseString2List(sStr, ["_"], []);

            if (llList2String(lSettings, 0) == "global" && llList2String(lSettings, 1) == "locked") g_iLocked=FALSE;
        }
    }
    listen( integer channel, string name, key id, string args ) {
    
        if (g_kSource) { if (g_kSource != id) return; } // already grabbed by another device
        
        list args = llParseStringKeepNulls(message, [","], []);
        
        if (llGetListLength(args) != 3) return;
        
        if (llList2Key(args, 1) != g_kWearer && llList2Key(args, 1) != (key) "ffffffff-ffff-ffff-ffff-ffffffffffff") return;
        
        integer index;
        string command;
        string ident = llList2String(args,0);
        list commands = llParseString2List(llList2String(args,2),["|"],[]);
        integer length = llGetListLength(commands);
        
        while (index < length) {
    
            command = llList2String(commands, index);
    
            if (llGetSubString(command,0,0)=="@") {
    
                if (command == "@clear" || command == "@detach=y") {
                    doRelease();
    
                } else {
                    llOwnerSay(command);
                    llRegionSayTo(id, RLV_RELAY_CHANNEL, ident + "," + (string)id + "," + command + ",ok");
    
                    list subargs = llParseString2List(command, ["="], []);
                    string behavior = llGetSubString(llList2String(subargs, 0), 1, -1);
                    integer index = llListFindList(g_lRestrictions, [behavior]);
                    string comtype = llList2String(subargs, 1);
                                    
                    if (index == -1 & (comtype == "n" || comtype == "add")) {
    
                        g_lRestrictions += [behavior];
                        g_kSource = id;
                        
                        llOwnerSay("@detach=add");
    
                        if (behavior == "unsit" && llGetAgentInfo(g_kWearer) & AGENT_SITTING) {
                            g_kSitID = llList2Key(llGetObjectDetails(g_kWearer, [OBJECT_ROOT]), 0);
                            g_kForcesitter = id;
                        }
                    }
                    else if (index != -1 && (comtype == "y" || comtype == "rem")) {
                        g_lRestrictions = llDeleteSubList(g_lRestrictions, index, index);
    
                        if (g_lRestrictions == []) {
                            g_kSource = NULL_KEY;
                            llOwnerSay("@detach=rem");
                        }
                        if (behavior == "unsit") g_kSitID = NULL_KEY;
                    }
                }
            } else if (command == "!pong" && id == g_kForcesitter && g_kSitID != NULL_KEY) {
                g_iResitStatus = 1;
    
            } else if (command == "!version") {
                llRegionSayTo(id, RLV_RELAY_CHANNEL, ident + "," + (string) id + ",!version,1100");
    
            } else if (command == "!implversion") {
                llRegionSayTo(id, RLV_RELAY_CHANNEL, ident + "," + (string) id + ",!implversion,ORG=0003/Satomi's Damn Fast Relay v4:OPENCOLLAR");
    
            } else if (command == "!x-orgversions") {
                llRegionSayTo(id, RLV_RELAY_CHANNEL, ident + "," + (string) id + ",!x-orgversions,ORG=0003");
    
            } else if (command == "!release") {
                doRelease();
                
            } else {
                llRegionSayTo(id, RLV_RELAY_CHANNEL, ident + "," + (string) id + "," + command + ",ko");
            }
            index++;
        }
    }
}