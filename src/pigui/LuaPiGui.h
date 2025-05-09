// Copyright © 2008-2025 Pioneer Developers. See AUTHORS.txt for details
// Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

#ifndef PIGUI_LUA_H
#define PIGUI_LUA_H

#include "lua/LuaRef.h"

#include <string>

struct ImGuiStyle;

namespace PiGui {

	// Get registered PiGui handlers.
	LuaRef GetHandlers();

	// Get registered PiGui themes.
	LuaRef GetThemes();

	// Get the EventQueue to be used for UI events
	LuaRef GetEventQueue();

	namespace Lua {
		void RegisterSandbox();

		void Init();
		void Uninit();
	} // namespace Lua

	// Emit all queued UI events
	void EmitEvents();

	// Run a lua PiGui handler.
	void RunHandler(double delta, const std::string &handler = "GAME");

	// Load a pigui theme into the specified ImGui style.
	void LoadTheme(ImGuiStyle &style, const std::string &theme);

	// FIXME: TEMPORARY to resolve loading order fiasco
	// we want themes up as soon as possible (because they're usually flat data objects)
	// so this function exists to load a theme out-of-order from Lua::InitModules
	void LoadThemeFromDisk(const std::string &theme);
} // namespace PiGui

#endif
