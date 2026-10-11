-- Nothing Liquid (NVIDIA laptops): which GPU Hyprland runs on.
-- With an integrated GPU and an NVIDIA one, a Hyprland that opens the NVIDIA GPU
-- keeps it awake all day. So: the integrated GPU, plus the NVIDIA one only when a
-- screen is plugged into one of its ports at login (many laptops wire HDMI to it;
-- plug that screen in before logging in). Apps still get the NVIDIA GPU when they
-- ask for it: prime-run <app>.
-- Uses /dev/dri/nl-igpu and nl-dgpu from nvidia/install.sh: AQ_DRM_DEVICES is a list
-- split on ":", which the /dev/dri/by-path names contain. Without them, nothing changes.

-- For each of the two: "screen" when a screen is connected to it. (The connectors'
-- status files hold what the GPU last saw: reading them doesn't wake it.)
local probe = io.popen([[
for g in igpu dgpu; do
  [ -e /dev/dri/nl-$g ] || continue
  card=$(basename "$(readlink -f /dev/dri/nl-$g)")
  if grep -qsx connected /sys/class/drm/"$card"-*/status; then echo "$g screen"; else echo "$g -"; fi
done]])
local found = {}
if probe then
    for g, screen in (probe:read("*a") or ""):gmatch("(%a+) (%S+)") do
        found[g] = screen
    end
    probe:close()
end

if found.dgpu == "screen" and found.igpu ~= "screen" then
    -- The NVIDIA GPU shows the desktop itself (a laptop switched to it in its firmware)
    hl.env("AQ_DRM_DEVICES", "/dev/dri/nl-dgpu")
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("NVD_BACKEND", "direct")
elseif found.igpu then
    hl.env("AQ_DRM_DEVICES", found.dgpu == "screen" and "/dev/dri/nl-igpu:/dev/dri/nl-dgpu" or "/dev/dri/nl-igpu")
end
