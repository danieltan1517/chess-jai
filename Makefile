asm.so: asm.c
	clang -shared -fpic -O3 -o asm.so asm.c

clean:
	rm asm.so
