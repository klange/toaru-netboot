/* vim: ts=4 sw=4 noexpandtab
 * This file is part of ToaruOS and is released under the terms
 * of the NCSA / University of Illinois License - see LICENSE.md
 * Copyright (C) 2015-2016 Kevin Lange
 *
 * netboot-init
 *
 *   Download, decompress, and mount a root filesystem from the
 *   network and run the `/bin/init` contained therein.
 *
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <syscall.h>
#include <sys/wait.h>
#include <sys/ioctl.h>
#include <sys/utsname.h>
#include <getopt.h>
#include <syscall.h>
#include <zlib.h>

#include "../../userspace/lib/http_parser.c"
#include "../../userspace/gui/terminal/terminal-font.h"
#include "../../kernel/include/video.h"

extern int mount(char* src,char* tgt,char* typ,unsigned long,void*);

#define SIZE 512

struct http_req {
	char domain[SIZE];
	char path[SIZE];
};

struct {
	int show_headers;
	const char * output_file;
	const char * cookie;
	FILE * out;
} fetch_options = {0};

static size_t size = 0;

#define TRACE(msg,...) do { \
	char tmp[512]; \
	sprintf(tmp, msg, ##__VA_ARGS__); \
	fprintf(stderr, "%s", tmp); \
	fflush(stderr); \
	print_string(tmp); \
} while(0)

static int has_video = 1;
static int width, height, depth;
static char * framebuffer;

#define char_height 12
#define char_width  8

static void set_point(int x, int y, uint32_t value) {
	uint32_t * disp = (uint32_t *)framebuffer;
	uint32_t * cell = &disp[y * width + x];
	*cell = value;
}

static void write_char(int x, int y, int val, uint32_t color) {
	if (val > 128) {
		val = 4;
	}
	uint8_t * c = number_font[val];
	for (uint8_t i = 0; i < char_height; ++i) {
		for (uint8_t j = 0; j < char_width; ++j) {
			if (c[i] & (1 << (8-j))) {
				set_point(x+j,y+i,color);
			} else {
				set_point(x+j,y+i,0xFF000000);
			}
		}
	}
}

#define LEFT_PAD 40
static int x = LEFT_PAD;
static int y = 0;
static void print_string(char * msg) {
	if (!has_video) return;
	while (*msg) {
		write_char(x,y,' ',0xFF000000);
		switch (*msg) {
			case '\n':
				x = LEFT_PAD;
				y += char_height;
				break;
			case '\033':
				msg++;
				if (*msg == '[') {
					msg++;
					if (*msg == 'G') {
						x = LEFT_PAD;
					}
				}
				break;
			default:
				write_char(x,y,*msg,0xFFFFFFFF);
				x += char_width;
				break;
		}
		write_char(x,y,'_',0xFF999999);
		msg++;
	}
}

void parse_url(char * d, struct http_req * r) {
	if (strstr(d, "http://") == d) {

		d += strlen("http://");

		char * s = strstr(d, "/");
		if (!s) {
			strcpy(r->domain, d);
			strcpy(r->path, "");
		} else {
			*s = 0;
			s++;
			strcpy(r->domain, d);
			strcpy(r->path, s);
		}
	} else {
		fprintf(stderr, "sorry, can't parse %s\n", d);
		exit(1);
	}
}

int next_is_content_length = 0;
int next_is_last_modified = 0;
size_t content_length = 0;
int callback_header_field (http_parser *p, const char *buf, size_t len) {
	if (fetch_options.show_headers) {
		fprintf(stderr, "Header field: %.*s\n", len, buf);
	}
	if (!strncmp(buf,"Content-Length",len)) {
		next_is_content_length = 1;
	} else {
		next_is_content_length = 0;
	}
	if (!strncmp(buf,"Last-Modified",len)) {
		next_is_last_modified = 1;
	} else {
		next_is_last_modified = 0;
	}
	return 0;
}

int callback_header_value (http_parser *p, const char *buf, size_t len) {
	if (fetch_options.show_headers) {
		fprintf(stderr, "Header value: %.*s\n", len, buf);
	}
	if (next_is_content_length) {
		char tmp[len+1];
		memcpy(tmp,buf,len);
		tmp[len] = '\0';
		content_length = atoi(tmp);
	}
	if (next_is_last_modified) {
		TRACE("Latest netboot image update dated %.*s\n", len, buf);
	}
	return 0;
}

#define BAR_WIDTH 20
#define bar_perc "||||||||||||||||||||"
#define bar_spac "                    "
int callback_body (http_parser *p, const char *buf, size_t len) {
	fwrite(buf, 1, len, fetch_options.out);
	size += len;
	TRACE("\033[G%6dkB",size/1024);
	if (content_length) {
		int percent = (size * BAR_WIDTH) / (content_length);
		TRACE(" / %6dkB [%.*s%.*s]", content_length/1024, percent,bar_perc,BAR_WIDTH-percent,bar_spac);
	}
	fflush(stderr);
	return 0;
}

static char * gz = "/tmp/netboot.img.gz";
static char * img = "/tmp/netboot.img";

int main(int argc, char * argv[]) {
	int _stdin  = open("/dev/null", O_RDONLY);
	int _stdout = open("/dev/ttyS0", O_WRONLY);
	int _stderr = open("/dev/ttyS0", O_WRONLY);

	if (_stdout < 0) {
		_stdout = open("/dev/null", O_WRONLY);
		_stderr = open("/dev/null", O_WRONLY);
	}

	int framebuffer_fd = open("/dev/fb0", O_RDONLY);
	if (framebuffer_fd < 0) {
		has_video = 0;
	} else {
		ioctl(framebuffer_fd, IO_VID_WIDTH,  &width);
		ioctl(framebuffer_fd, IO_VID_HEIGHT, &height);
		ioctl(framebuffer_fd, IO_VID_DEPTH,  &depth);
		ioctl(framebuffer_fd, IO_VID_ADDR,   &framebuffer);
		ioctl(framebuffer_fd, IO_VID_SIGNAL, NULL);
	}

	TRACE("\n\nToaruOS Netboot Host\n\n");
	struct utsname u;
	uname(&u);
	TRACE("%s %s %s %s\n\n", u.sysname, u.nodename, u.release, u.version);

	if (has_video) {
		TRACE("Display is %dx%d (%d bpp), framebuffer at 0x%x\n", width, height, depth, framebuffer);
	} else {
		TRACE("No video? framebuffer_fd = %d\n", framebuffer_fd);
	}

	TRACE("\n");
	TRACE("Sleeping for a moment to let network initialize...\n");
	sleep(2);

	struct http_req my_req;
	parse_url("http://toaruos.org/netboot.img.gz", &my_req);

	char file[100];
	sprintf(file, "/dev/net/%s", my_req.domain);

	TRACE("Fetching from %s...\n", my_req.domain);

	fetch_options.out = fopen(gz,"w");

	FILE * f = fopen(file,"r+");
	if (!f) {
		TRACE("ERROR: Network does not seem to be available, or unable to reach host.\n");
		TRACE("       Please check your VM configuration.\n");
		return 0;
	}

	TRACE("Connection established.\n");

	fprintf(f,
		"GET /%s HTTP/1.0\r\n"
		"User-Agent: curl/7.35.0\r\n"
		"Host: %s\r\n"
		"Accept: */*\r\n"
		"\r\n", my_req.path, my_req.domain);
	http_parser_settings settings;
	memset(&settings, 0, sizeof(settings));
	settings.on_header_field = callback_header_field;
	settings.on_header_value = callback_header_value;
	settings.on_body = callback_body;

	http_parser parser;
	http_parser_init(&parser, HTTP_RESPONSE);

	fprintf(stderr,"Downloading netboot payload...\n");

	while (!feof(f)) {
		char buf[1024];
		memset(buf, 0, sizeof(buf));
		size_t r = fread(buf, 1, 1024, f);
		http_parser_execute(&parser, &settings, buf, r);
	}

	TRACE("\nDone.\n");

	fflush(fetch_options.out);
	fclose(fetch_options.out);

	TRACE("Decompressing payload...\n");
	gzFile src = gzopen(gz, "r");

	if (!src) return 1;

	FILE * dest = fopen(img, "w");

	if (!dest) return 1;

	while (!gzeof(src)) {
	 char buf[1024];
	 int r = gzread(src, buf, 1024);
	 fwrite(buf, r, 1, dest);
	}

	TRACE("Done.\n");

	fclose(dest);

	unlink(gz);

	TRACE("Mounting filesystem...\n");
	mount(img, "/", "ext2", 0, NULL);

	TRACE("Executing init...\n");
	char * const _argv[] = {
		"/bin/init",
		"live-welcome",
		NULL,
	};
	execve("/bin/init",_argv,NULL);

	TRACE("ERROR: If you are seeing this, there was a problem\n");
	TRACE("       executing the init binary from the downloaded\n");
	TRACE("       filesystem. This may indicate a corrupted\n");
	TRACE("       download. Please try again.\n");

	return 0;
}
