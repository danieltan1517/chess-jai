asm.so: asm.c
	clang -shared -fpic -O2 -o asm.so asm.c

clean:
	rm asm.so
