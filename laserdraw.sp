#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Promises"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "LaserDraw",
	author = PLUGIN_AUTHOR,
	description = "Draw with a laser",
	version = PLUGIN_VERSION,
	url = ""
};

int RainbowColors[12][4] =  { {255, 0, 0, 255}, {255, 128, 0, 255}, {255, 255, 0, 255}, {128, 255, 0, 255}, {0, 255, 0, 255}, {0, 255, 128, 255},  {0, 255, 255, 255}, {0, 128, 255, 255}, {0, 0, 255, 255}, {128, 0, 255, 255}, {255, 0, 255, 255}, {255, 0, 128, 255} };

float g_fLastLaser[MAXPLAYERS+1][3];
bool g_bLaserE[MAXPLAYERS+1] = {false, ...};

int g_sprite;
int g_iLaserMode[MAXPLAYERS + 1];
int g_iLaserShowMode[MAXPLAYERS + 1];
int g_iPivotMode[MAXPLAYERS + 1];


float g_fLaserDuration[MAXPLAYERS + 1];
float g_fLaserDistance[MAXPLAYERS + 1];
float g_fLaserWidth[MAXPLAYERS + 1];


Handle g_hCookieLaserMode;
Handle g_hCookieDuration;
Handle g_hCookieDistance;
Handle g_hCookieShowMode;
Handle g_hCookieDefault;
Handle g_hCookieWidth;
Handle g_hCookiePivot;


public void OnPluginStart()
{
	
	CreateConVar("sm_lazer_version", PLUGIN_VERSION, "laserdraw", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	RegConsoleCmd("sm_laser", SM_LASER);
	
	RegConsoleCmd("+laser", SM_LASER_P);
	RegConsoleCmd("-laser", SM_LASER_R);
	
	RegConsoleCmd("laser_width", SM_WIDTH);
	RegConsoleCmd("laser_duration", SM_DURATION);
	RegConsoleCmd("laser_distance", SM_DISTANCE);
	RegConsoleCmd("laser_pivot", SM_PIVOT);
	
	g_hCookieLaserMode = RegClientCookie("laser_mode", "ladr_mode", CookieAccess_Public);
	g_hCookieDuration = RegClientCookie("laser_duration", "ladr_duration", CookieAccess_Public);
	g_hCookieDistance = RegClientCookie("laser_distance", "ladr_distance", CookieAccess_Public);
	g_hCookieWidth = RegClientCookie("laser_width", "ladr_width", CookieAccess_Public);
	g_hCookieShowMode = RegClientCookie("laser_local", "ladr_local", CookieAccess_Public);
	g_hCookiePivot = RegClientCookie("laser_pivot", "laser_pivot", CookieAccess_Public);
	g_hCookieDefault = RegClientCookie("laser_default", "laser_default", CookieAccess_Public);
	
	
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) )
		{
			OnClientPutInServer(i);
			OnClientCookiesCached(i);
		}
	}
	
}

public void OnClientCookiesCached(int client)
{
	char sCookie[8];
	GetClientCookie(client, g_hCookieDefault, sCookie, sizeof(sCookie));
	if (StringToInt(sCookie) == 0)
	{
		SetCookieInt(client, g_hCookieLaserMode, 2);
		SetCookieFloat(client, g_hCookieDuration, 10.0);
		SetCookieFloat(client, g_hCookieDistance, 64.0);
		SetCookieFloat(client, g_hCookieWidth, 1.0);
		SetCookieInt(client, g_hCookieShowMode, 0);
		SetCookieInt(client, g_hCookiePivot, 0);
		SetCookieInt(client, g_hCookieDefault, 1);
	}
	GetClientCookie(client, g_hCookieLaserMode, sCookie, sizeof(sCookie));
	g_iLaserMode[client] = StringToInt(sCookie);
	
	GetClientCookie(client, g_hCookieDuration, sCookie, sizeof(sCookie));
	g_fLaserDuration[client] = StringToFloat(sCookie);
	GetClientCookie(client, g_hCookieDistance, sCookie,sizeof(sCookie));
	g_fLaserDistance[client] = StringToFloat(sCookie);
	GetClientCookie(client, g_hCookieWidth, sCookie, sizeof(sCookie));
	g_fLaserWidth[client] = StringToFloat(sCookie);
	GetClientCookie(client, g_hCookieShowMode, sCookie, sizeof(sCookie));
	g_iLaserShowMode[client] = StringToInt(sCookie);
	GetClientCookie(client, g_hCookiePivot, sCookie, sizeof(sCookie));
	g_iPivotMode[client] = StringToInt(sCookie);
}
public void OnMapStart()
{
	
	g_sprite = PrecacheModel("materials/sprites/laserbeam.vmt");

}

public void OnClientPutInServer(int client)
{

	g_bLaserE[client] = false;
	g_fLastLaser[client][0] = 0.0;
	g_fLastLaser[client][1] = 0.0;
	g_fLastLaser[client][2] = 0.0;
}

public Action SM_LASER(int client, int args)
{
	OpenLaserMenu(client);
}

public Action SM_LASER_P(int client, int args)
{
	g_bLaserE[client] = true;
	laser_p_m(client);
}

public Action SM_LASER_R(int client, int args)
{

	g_bLaserE[client] = false;
	g_fLastLaser[client][0] = 0.0;
	g_fLastLaser[client][1] = 0.0;
	g_fLastLaser[client][2] = 0.0;

}

public Action SM_WIDTH(int client, int args)
{

	if (args >= 1)
	{
		char strWidth[32];
		GetCmdArg(1, strWidth, 32);
		float flWidth = StringToFloat(strWidth);
		
		if (flWidth > 25.0 && (!GetUserFlagBits(client) & ADMFLAG_ROOT))
		{
			flWidth = 25.0;
		}
		else
		{
			if (flWidth > 256.0)
			{
				flWidth = 256.0;
			}
		}
		if (flWidth < 0.128)
		{
			flWidth = 0.128;
		}
		g_fLaserWidth[client] = flWidth;
		SetCookieFloat(client, g_hCookieWidth, g_fLaserWidth[client]);
	}
	ReplyToCommand(client, "Your laser's width is %.2f", g_fLaserWidth[client]);
	return Plugin_Handled;

}

public Action SM_DURATION(int client, int args)
{
	if (args >= 1)
	{
		char sDuration[32];
		GetCmdArg(1, sDuration, 32);
		float flDuration = StringToFloat(sDuration);
		if (flDuration > 25.0)
		{
			flDuration = 25.0;
		}
		if (flDuration < 0.0502)
		{
			flDuration = 0.0;
		}
		g_fLaserDuration[client] = flDuration;
		SetCookieFloat(client, g_hCookieDuration, g_fLaserDuration[client]);
	}
	if (g_fLaserDuration[client] == 0.0)
	{
		ReplyToCommand(client, "Your laser's duration is infinite");
	}
	else
	{
		ReplyToCommand(client, "Your laser's duration is %.2f seconds", g_fLaserDuration[client]);
	}
	return Plugin_Handled;
}

public Action SM_PIVOT(int client, int args)
{

	g_iPivotMode[client] = !g_iPivotMode[client];
	
	if(g_iPivotMode[client] == 1)
	{
		PrintToChat(client, "PivotMode: enabled");
	}
	else if(g_iPivotMode[client] == 0)
	{
		PrintToChat(client, "PivotMode: disabled");
	}

}


public Action SM_DISTANCE(int client, int args)
{
	
	if (args >= 1)
	{
		char sDist[32];
		GetCmdArg(1, sDist, sizeof(sDist));
		float flDist = StringToFloat(sDist);
		if (flDist > 8192.0)
		{
			flDist = 8192.0;
		}
		if (flDist < 0.0)
		{
			flDist = 0.0;
		}
		g_fLaserDistance[client] = flDist;
		SetCookieFloat(client, g_hCookieDistance, g_fLaserDistance[client]);
	}
	ReplyToCommand(client, "Your laser's fixed distance is %.2f", g_fLaserDistance[client]);
	return Plugin_Handled;

}

public void OpenLaserMenu(int client)
{

	char sBuffer[128];
	
	Handle panel = CreatePanel();
	SetPanelTitle(panel, "LaserMenu");
	
	FormatEx(sBuffer, sizeof(sBuffer), "Paint - [%s]\n", (g_bLaserE[client]) ? "x" : " ");
	DrawPanelItem(panel, sBuffer);
	
	FormatEx(sBuffer, sizeof(sBuffer), "%s\n", g_iLaserMode[client] == 0 ? "Mode: View Fixed Distance" : (g_iLaserMode[client] == 1 ? "Mode: Feet" : "Mode: Crosshair"));
	DrawPanelItem(panel, sBuffer);
	
	FormatEx(sBuffer, sizeof(sBuffer), "%s\n", g_iLaserShowMode[client] == 0 ? "Mode: Specs" : (g_iLaserShowMode[client] == 1 ? "Mode: only you" : "Mode: everyone"));
	DrawPanelItem(panel, sBuffer);
	
	DrawPanelItem(panel, "Print commands to console");
	
	DrawPanelItem(panel, "Exit", ITEMDRAW_CONTROL);
	SendPanelToClient(panel, client, LaserMenu, 0);
	CloseHandle(panel);
}

public int LaserMenu(Handle menu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (item)
			{
				case 1://Paint
				{
					g_bLaserE[client] = !g_bLaserE[client];
					laser_p_m(client);
					OpenLaserMenu(client);
				}
				case 2: // laser mode
				{
					g_iLaserMode[client] = (g_iLaserMode[client] + 1) % 3;
					SetCookieInt(client, g_hCookieLaserMode, g_iLaserMode[client]);
					OpenLaserMenu(client);
				}
				case 3://lasershow
				{
					g_iLaserShowMode[client] = (g_iLaserShowMode[client] + 1) % 3;
					SetCookieInt(client, g_hCookieShowMode, g_iLaserShowMode[client]);
					OpenLaserMenu(client);
				}
				case 4:
				{
					PrintCommands(client);
					OpenLaserMenu(client);
				}
			}
		}
	}
}

public void PrintCommands(int client)
{
	PrintToChat(client, "Check your console for commands");
	PrintToConsole(client, "	Laser Commands			");
	PrintToConsole(client, "+laser				-> enable laser");
	PrintToConsole(client, "-laser 				-> disable laser");
	PrintToConsole(client, "laser_width {number} 		-> sets laser width");
	PrintToConsole(client, "laser_duration {number}		-> sets beam duration");
	PrintToConsole(client, "laser_distance 			-> sets fixed distance distance");
	PrintToConsole(client, "laser_pivot            		-> enables or disables pivot");
	
}

public void laser_p_m(int client) 
{
	if(g_bLaserE[client])
	{
		if(g_iLaserMode[client] == 0)
			TraceEyeDist(client, g_fLastLaser[client]);
		else if(g_iLaserMode[client] == 1)
			TraceFeet(client, g_fLastLaser[client]);
		else if(g_iLaserMode[client] == 2)
			TraceEyeInf(client, g_fLastLaser[client]);
	}
	else if (g_bLaserE[client] == false)
	{
		g_fLastLaser[client][0] = 0.0;
		g_fLastLaser[client][1] = 0.0;
		g_fLastLaser[client][2] = 0.0;
	}
}

public Action CMD_laser_m(int client, int args) 
{
	g_fLastLaser[client][0] = 0.0;
	g_fLastLaser[client][1] = 0.0;
	g_fLastLaser[client][2] = 0.0;
	g_bLaserE[client] = false;
	return Plugin_Handled;
}

stock void LaserP(int client, float start[3], float end[3], int color[4])
{
	TE_SetupBeamPoints(start, end, g_sprite, 0, 0, 0, g_fLaserDuration[client], g_fLaserWidth[client] / 2.0, g_fLaserWidth[client] / 2.0, 0, 0.0, color, 0);
	
	int iTargets;
	int[] t = new int[MaxClients];
	if(g_iPivotMode[client] == 1)
	{
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				if(!IsPlayerAlive(i) && (IsPlayerAlive(client) && client == GetEntPropEnt(i, Prop_Data, "m_hObserverTarget"))) 
				{
					iTargets++;
					t[iTargets] = i;
				}
				else if(!IsPlayerAlive(client) && GetEntPropEnt(client, Prop_Data, "m_hObserverTarget") == GetEntPropEnt(i, Prop_Data, "m_hObserverTarget"))
				{
					iTargets++;
					t[iTargets] = i;				
				}
				else if(client != i && (IsPlayerAlive(i) && !IsPlayerAlive(client) && i == GetEntPropEnt(client, Prop_Data, "m_hObserverTarget")))
				{
					iTargets++;
					t[iTargets] = i;
				}
				else
				{	
					continue;
				}
			}
			else
			{
				continue;
			}
		}
	}

	
	if(g_iLaserShowMode[client] == 0) //not working as intended rn
	{
		int target;
		for(int c = 1; c <= MaxClients; c++)
		{
			if(!IsClientInGame(c))
				continue;
				
			if(IsFakeClient(c))
				continue;
			
			if(IsPlayerAlive(c))
			{
				target = c;
			}
			else
			{
				int ObserverTarget = GetEntPropEnt(c, Prop_Send, "m_hObserverTarget");
				int ObserverMode   = GetEntProp(c, Prop_Send, "m_iObserverMode");
				
				if((0 < ObserverTarget <= MaxClients) && (ObserverMode == 4 || ObserverMode == 5 || ObserverMode == 6))
					target = ObserverTarget;
				else
					continue;
			}
			
		}
		TE_SendToClient(target);
		if(g_iPivotMode[target] == 1)
			TE_Send(t, iTargets);
		
	}
	else if(g_iLaserShowMode[client] == 1)
	{
		TE_SendToClient(client);
		if(g_iPivotMode[client] == 1)
			TE_Send(t, iTargets);
	}
	else if(g_iLaserShowMode[client] == 2)
	{
		TE_SendToAll();
		if(g_iPivotMode[client] == 1)
			TE_Send(t, iTargets);
	}
}

void TraceEyeInf(int client, float pos[3]) 
{
	float vAngles[3]; 
	float vOrigin[3];
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);
	TR_TraceRayFilter(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceRayDontHitSelf);
	if(TR_DidHit(INVALID_HANDLE)) 
		TR_GetEndPosition(pos, INVALID_HANDLE);
	return;
}

void TraceEyeDist(int client, float pos[3]) 
{
	float vAngles[3]; 
	float vOrigin[3];
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);
	float vDirection[3];
	
	GetAngleVectors(vAngles, vDirection, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(vDirection, g_fLaserDistance[client]);
	
	AddVectors(vOrigin, vDirection, pos);
	
	return;
}

void TraceFeet(int client, float pos[3])
{
	GetClientAbsOrigin(client, pos);

	return;
}
public bool TraceRayDontHitSelf(int entity, int mask, any data)
{
	return entity != data && !(0 < entity <= MaxClients);
}

stock void SetCookieString(int client, Handle hCookie, char[] sCookie)
{
	SetClientCookie(client, hCookie, sCookie);
}

stock void SetCookieFloat(int client, Handle hCookie, float n)
{
	char sCookie[64];
	FloatToString(n, sCookie, sizeof(sCookie));
	SetClientCookie(client, hCookie, sCookie);
}

stock void SetCookieInt(int client, Handle hCookie, int n)
{
	char sCookie[64];
	IntToString(n, sCookie, sizeof(sCookie));
	SetClientCookie(client, hCookie, sCookie);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount)
{
	if (IsFakeClient(client))
	{
		return Plugin_Continue;
	}
	float pos[3] = 0.0;	
	if (IsClientInGame(client))
	{
		if (g_bLaserE[client])
		{
			if(g_iLaserMode[client] == 0)
				TraceEyeDist(client, pos);
			else if(g_iLaserMode[client] == 1)
				TraceFeet(client, pos);
			else if(g_iLaserMode[client] == 2)
				TraceEyeInf(client, pos);
				
			if (GetVectorDistance(pos, g_fLastLaser[client], false) > g_fLaserWidth[client])
			{
				if (!(0.0 == g_fLastLaser[client][0] && 0.0 == g_fLastLaser[client][1] && 0.0 == g_fLastLaser[client][2]))
				{
					LaserP( client, g_fLastLaser[client], pos, RainbowColors[tickcount % 12]);
	
				}
				g_fLastLaser[client][0] = pos[0];
				g_fLastLaser[client][1] = pos[1];
				g_fLastLaser[client][2] = pos[2];
			}
		}
	}
	return Plugin_Continue;
}
