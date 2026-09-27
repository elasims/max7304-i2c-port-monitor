#include <stdio.h>
#include "xil_io.h"
#include "xparameters.h"
#include "xil_printf.h"

#define IIC_BASEADDR   XPAR_MYIP_IIC_ELA_0_S00_AXI_BASEADDR

#define CTRL_OFF 0x00
#define STATUS_OFF 0x04
#define RDATA_OFF 0x08

#define op_start 0
#define op_write 1
#define op_read 2
#define op_done 3

#define slave_addr_w 0x38
#define slave_addr_r 0x39
#define slave_gcfg 0x40
#define slave_dir 0x34
#define slave_values 0x3A

void i2c_op (int op, u8 data, int nack) {
	u32 ctrl = ((u32)(nack & 1) << 11) | ((u32)data << 3) | ((u32)op << 1) | 1;
	Xil_Out32 (IIC_BASEADDR + CTRL_OFF, ctrl);
	while (Xil_In32(IIC_BASEADDR + STATUS_OFF) & 0x1){
	}
}

u8 i2c_rdata(void) {
    return (u8)(Xil_In32(IIC_BASEADDR + RDATA_OFF) & 0xFF);
}

void max7304_write_reg(u8 reg, u8 val) {
    i2c_op(op_start, 0, 0);
    i2c_op(op_write, slave_addr_w, 0);
    i2c_op(op_write, reg, 0);
    i2c_op(op_write, val, 0);
    i2c_op(op_done, 0, 0);
}

u8 max7304_read_reg(u8 reg) {
    i2c_op(op_start, 0, 0);
    i2c_op(op_write, slave_addr_w, 0);
    i2c_op(op_write, reg, 0);
    i2c_op(op_start, 0, 0);
    i2c_op(op_write, slave_addr_r, 0);
    i2c_op(op_read, 0, 1);
    u8 val = i2c_rdata();
    i2c_op(op_done, 0, 0);
    return val;
}

u8 dir_mask = 0;

int main () {

	int port;
	xil_printf("MAX7304 is ready. \r\n");

	max7304_write_reg(slave_gcfg, 0x01);
	xil_printf("MAX7304 is ready. \r\n");

	while (1) {
		printf("Which port do you want to set as input? (0-7):");
		scanf("%d", &port);
		if (port == -1) break;
		if (port < 0 || port > 7) {
			printf("Invalid port. \r\n");
			continue;
		}
		dir_mask |= (1 << port);
	}
	max7304_write_reg(slave_dir, dir_mask);

	u8 vals = max7304_read_reg(slave_values);
	printf("Selected mask: 0x%02X, current values: 0x%02X\r\n", dir_mask, vals);

	for (int i = 0; i < 8; i++) {
	    if (dir_mask & (1 << i)) {
	        printf("Port %d is %s\r\n", i, (vals & (1 << i)) ? "OPEN" : "closed");
	    }
	}
return 0;
}
