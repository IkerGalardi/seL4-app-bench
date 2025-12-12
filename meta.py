from sdfgen import SystemDescription, Sddf, DeviceTree

ProtectionDomain = SystemDescription.ProtectionDomain
MemoryRegion = SystemDescription.MemoryRegion
Map = SystemDescription.Map
Channel = SystemDescription.Channel
Arch = SystemDescription.Arch

sddf = Sddf("vendor/sddf")
sdf = SystemDescription(Arch.AARCH64, 0x60000000)

dtb = DeviceTree(open("qemuvirt.dtb", "rb").read())

webserver = ProtectionDomain("webserver", "build/webserver.elf")

serial_node = dtb.node("pl011@9000000")
serial_driver = ProtectionDomain(
    "serial_driver", "build/serial_driver.elf", priority=200
)
serial_virt_tx = ProtectionDomain(
    "serial_virt_tx", "build/serial_virt_tx.elf", priority=199
)
serial_virt_rx = ProtectionDomain(
    "serial_virt_rx", "build/serial_virt_rx.elf", priority=199
)
serial_system = Sddf.Serial(
    sdf, serial_node, serial_driver, virt_tx=serial_virt_tx, virt_rx=serial_virt_rx
)

sdf.add_pd(serial_driver)
sdf.add_pd(serial_virt_tx)
sdf.add_pd(serial_virt_rx)
sdf.add_pd(webserver)
serial_system.add_client(webserver)

assert serial_system.connect()
assert serial_system.serialise_config("build/")


with open("webserver.system", "w") as f:
    f.write(sdf.render())
