data "hcloud_volume" "rd-test-volume" {
  id = "123456789"
  name = "rd-test-volume"
  size = 1024
  linux_device = "myvolume"
}

resource "hcloud_network" "rd-test-net" {
  name     = "rd-test-net"
  ip_range = "10.10.10.0/24"
}

