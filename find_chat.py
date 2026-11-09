"""Find a chat id by name. Usage: python3 find_chat.py "name" """
import sys

from bridge import api

query = sys.argv[1].lower()
matches = []
for contact in api("/api/contacts/all?session=default"):
    name = contact.get("name") or contact.get("pushname") or contact.get("shortName") or ""
    if query in name.lower():
        matches.append((contact.get("id"), name))
for chat_id, name in matches or [("", "no match")]:
    print(chat_id, "\t", name)
