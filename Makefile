asm.so: asm.c
	clang -shared -fpic -o asm.so asm.c

clean:
	rm asm.so
