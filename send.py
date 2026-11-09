"""Send one text message. Usage: python3 send.py CHAT_ID "text" """
import sys

from bridge import api

chat_id, text = sys.argv[1], sys.argv[2]
api("/api/sendText", {"session": "default", "chatId": chat_id, "text": text}, timeout=30)
print("sent")
