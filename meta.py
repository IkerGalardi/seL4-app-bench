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

eth_node = dtb.node("virtio_mmio@a003e00")
eth_driver = ProtectionDomain("eth_driver", "build/eth_driver.elf", priority=199)
network_virt_tx = ProtectionDomain(
    "network_virt_tx", "build/network_virt_tx.elf", priority=199
)
network_virt_rx = ProtectionDomain(
    "network_virt_rx", "build/network_virt_rx.elf", priority=199
)
network_copy = ProtectionDomain("network_copy", "build/network_copy.elf", priority=199)
network_system = Sddf.Net(sdf, eth_node, eth_driver, network_virt_tx, network_virt_rx)
liblwip = Sddf.Lwip(sdf, network_system, webserver)


sdf.add_pd(serial_driver)
sdf.add_pd(serial_virt_tx)
sdf.add_pd(serial_virt_rx)
sdf.add_pd(eth_driver)
sdf.add_pd(network_virt_tx)
sdf.add_pd(network_virt_rx)
sdf.add_pd(network_copy)
sdf.add_pd(webserver)
serial_system.add_client(webserver)
network_system.add_client_with_copier(webserver, network_copy)

assert serial_system.connect()
assert serial_system.serialise_config("build/")
assert liblwip.connect()
assert liblwip.serialise_config("build/")
assert network_system.connect()
assert network_system.serialise_config("build/")


with open("webserver.system", "w") as f:
    f.write(sdf.render())
