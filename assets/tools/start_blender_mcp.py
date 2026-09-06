import bpy, addon_utils
def go():
    try:
        addon_utils.enable("addon", default_set=True, persistent=True)
    except Exception as e:
        print("enable failed:", e)
    try:
        if not bpy.context.scene.blendermcp_server_running:
            bpy.ops.blendermcp.start_server()
        print("MCP server running:", bpy.context.scene.blendermcp_server_running)
    except Exception as e:
        print("start failed:", e)
        return 2.0
    return None
bpy.app.timers.register(go, first_interval=2.0)
