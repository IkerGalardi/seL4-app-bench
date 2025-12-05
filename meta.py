import argparse
from dataclasses import dataclass
from sdfgen import SystemDescription, Sddf, DeviceTree

ProtectionDomain = SystemDescription.ProtectionDomain
MemoryRegion = SystemDescription.MemoryRegion
Map = SystemDescription.Map
Channel = SystemDescription.Channel
Arch = SystemDescription.Arch

sdf = SystemDescription(Arch.AARCH64, 0x60000000)

webserver = ProtectionDomain("webserver", "build/webserver.elf")
sdf.add_pd(webserver)

with open("webserver.system", "w") as f:
    f.write(sdf.render())
