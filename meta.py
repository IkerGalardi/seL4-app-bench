import json
import sys

from sdfgen import DeviceTree, Sddf, SystemDescription

ProtectionDomain = SystemDescription.ProtectionDomain
MemoryRegion = SystemDescription.MemoryRegion
Map = SystemDescription.Map
Channel = SystemDescription.Channel
Arch = SystemDescription.Arch

if len(sys.argv) != 2:
    print("META: please provide a core configuration")
    exit(1)
core_conf = json.loads(open(sys.argv[1]).read())

sddf = Sddf("vendor/sddf")
sdf = SystemDescription(Arch.AARCH64, 0x60000000)

dtb = DeviceTree(open("qemuvirt.dtb", "rb").read())

webserver = ProtectionDomain("webserver", "build/webserver.elf")

serial_node = dtb.node("pl011@9000000")
serial_driver = ProtectionDomain(
    "serial_driver",
    "build/serial_driver.elf",
    priority=100,
    cpu=core_conf["serial_driver"],
)
serial_virt_tx = ProtectionDomain(
    "serial_virt_tx",
    "build/serial_virt_tx.elf",
    priority=99,
    cpu=core_conf["serial_virt_tx"],
)
serial_virt_rx = ProtectionDomain(
    "serial_virt_rx",
    "build/serial_virt_rx.elf",
    priority=99,
    cpu=core_conf["serial_virt_rx"],
)
serial_system = Sddf.Serial(
    sdf, serial_node, serial_driver, virt_tx=serial_virt_tx, virt_rx=serial_virt_rx
)

timer_node = dtb.node("timer")
timer_driver = ProtectionDomain(
    "timer_driver",
    "build/timer_driver.elf",
    priority=101,
    cpu=core_conf["timer_driver"],
)
timer_system = Sddf.Timer(sdf, timer_node, timer_driver)

eth_node = dtb.node("virtio_mmio@a003e00")
eth_driver = ProtectionDomain(
    "eth_driver",
    "build/eth_driver.elf",
    priority=101,
    budget=20000,
    cpu=core_conf["eth_driver"],
)
network_virt_tx = ProtectionDomain(
    "network_virt_tx",
    "build/network_virt_tx.elf",
    priority=100,
    budget=20000,
    cpu=core_conf["network_virt_tx"],
)
network_virt_rx = ProtectionDomain(
    "network_virt_rx",
    "build/network_virt_rx.elf",
    priority=99,
    cpu=core_conf["network_virt_rx"],
)
network_copy = ProtectionDomain(
    "network_copy",
    "build/network_copy.elf",
    priority=97,
    budget=20000,
    cpu=core_conf["network_copy"],
)
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
sdf.add_pd(timer_driver)
timer_system.add_client(webserver)
serial_system.add_client(webserver)
network_system.add_client_with_copier(webserver, network_copy)

assert serial_system.connect()
assert serial_system.serialise_config("build/")
assert timer_system.connect()
assert timer_system.serialise_config("build/")
assert liblwip.connect()
assert liblwip.serialise_config("build/")
assert network_system.connect()
assert network_system.serialise_config("build/")


with open("webserver.system", "w") as f:
    f.write(sdf.render())
