all : help

help:
	@echo "支持下面命令:"
	@echo "make build       # 编译 skynet"
	@echo "make start       # 开服"
	@echo "make client      # 测试客户端"

build: 
	@cd skynet && make linux

start:
	@./skynet/skynet etc/config.cfg

client:
	@rlwrap ./skynet/skynet etc/config.client

console:
	@rlwrap telnet 127.0.0.1 8000