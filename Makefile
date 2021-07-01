asm.so: asm.c asm.h
	clang -shared -fpic -o asm.so asm.c

clean:
	rm asm.so
