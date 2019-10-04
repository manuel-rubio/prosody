-- Prosody IM
-- Copyright (C) 2019 Manuel Rubio
--
-- This project is MIT/X11 licensed. Please see the
-- COPYING file in the source package for more information.
--
-- This module implements XEP-0372: References
--

local xmlns_references = 'urn:xmpp:reference:0'

module:add_feature(xmlns_references)

local mod_muc = module:depends"muc";
local get_room_from_jid = mod_muc.get_room_from_jid;
local jid = require "util.jid";
local st = require "util.stanza";

local function get_users(self, users)
	for occupant_jid, occupant in self:each_occupant() do
		_, _, nick = jid.split(occupant_jid)
		module:log("debug", "user %s with jid %s", nick, occupant.jid)
		users[nick] = occupant.jid
	end
end

local function gen_tag(jid, init, ending)
	return st.stanza("reference", {
		['xmlns'] = xmlns_references;
		['begin'] = tostring(init - 1);
		['end']   = tostring(ending - 1);
		['type']  = 'mention';
		['uri']   = 'xmpp:' .. jid;
	})
end

local function add_references(str, init, users, stanza)
	local init, ending = str:find("%a+", init)
	if init then
		local user = string.sub(str, init, ending)
		if users[user] then
			module:log("debug", "found! %s with jid %s", user, users[user])
			stanza:add_child(gen_tag(users[user], init, ending))
		else
			module:log("debug", "not found %s", user)
		end
		add_references(str, ending + 1, users, stanza)
	end
end

local function handle_references(event)
	local stanza = event.stanza
	if stanza.attr.type == "groupchat" then
		local room_jid = jid.bare(stanza.attr.to);
		local room = get_room_from_jid(room_jid);
		local body = stanza:get_child_text("body")

		if room and body then
			module:log("debug", "Body => %s", tostring(body))
			local refs = {}
			local users = {}
			get_users(room, users)
			add_references(body, 0, users, stanza)
			module:log("debug", "Stanza =>\n--------\n%s\n---------\n", tostring(stanza))
		end
	end
end

local prio_in = 100
module:hook("message/bare", handle_references, prio_in)
