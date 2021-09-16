# output.tf > outputs whatever you define to the terminal

output "vpc_id" {
    value = "${aws_vpc.sre_will_vpc_tf.id}"
}

output "internet_gateway_id" {
    value = "${aws_internet_gateway.sre_will_IG.id}"
}

output "subnet_id" {
    value = "${aws_subnet.sre_will_subnet_tf.id}"
}

output "security_group_id" {
    value = "${aws_security_group.sre_will_app_group.id}"
}

output "route_table_id" {
    value = "${aws_vpc.sre_will_vpc_tf.default_route_table_id}"
}