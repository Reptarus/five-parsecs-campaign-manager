
import sys
import json
import uuid

def send_mcp_request(tool_name, arguments):
    request = {
        "request_id": str(uuid.uuid4()),
        "tool_name": tool_name,
        "arguments": arguments
    }

    with open(f"/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/mcp_bridge/requests/{request['request_id']}.json", "w") as f:
        json.dump(request, f)

if __name__ == "__main__":
    tool_name = sys.argv[1]
    arguments = json.loads(sys.argv[2])
    send_mcp_request(tool_name, arguments)
