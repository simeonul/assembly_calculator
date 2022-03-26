.386
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern malloc: proc
extern memset: proc

includelib canvas.lib
extern BeginDrawing: proc
extern printf: proc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;declaram simbolul start ca public - de acolo incepe executia
public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sectiunile programului, date, respectiv cod
.data
;aici declaram date
window_title DB "Calculator",0
area_width EQU 260
area_height EQU 460
area DD 0

val_counter DD 0
zece DD 10
doi DB 2

counter DD 0 ; numara evenimentele de tip timer
counter_cifre DD -1 ; numara cate cifre avem in componenta unui numar pe ecran
cifre_sterse DD 0
val_sterse DD 0
caracter DD 0
finished DD 0 ; semnaleaza incheierea operatiei actuale

primul_termen DD 0
al_doilea_termen DD 0

pressed_symbol DD 0 ; semnaleaza apasarea unuia dintre simbolurile pentru operatii a fost apasat
pressed_plus DD 0
pressed_minus DD 0
pressed_inmultire DD 0
pressed_impartire DD 0
changed_sign1 DD 0 ; counter pentru numarul de dati in care a fost apasat butonul pt schimbarea simbolului primului termen
changed_sign2 DD 0

rezultat_up DD 0
rezultat_down DD 0
str_rezultat_up DB 32 dup(0), 0
str_rezultat DB 32 dup(0), 0
val_rezultat DD 0

arg1 EQU 8
arg2 EQU 12
arg3 EQU 16
arg4 EQU 20

symbol_width EQU 10
symbol_height EQU 20
include digits.inc
include letters.inc
include symbols.inc

button_size EQU 60 ; o latura a unui buton are 60 px

format DB "%d %d", 13, 10, 0
format2 DB "%c", 0
format3 DB "%d     ",13, 10, 0
trash DD 0


.code
; procedura make_text afiseaza o litera sau o cifra la coordonatele date
; arg1 - simbolul de afisat (litera sau cifra)
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y
make_text proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1] ; citim simbolul de afisat
	cmp eax, 'A'
	jl make_digit
	cmp eax, 'Z'
	jg make_digit
	sub eax, 'A'
	lea esi, letters
	jmp draw_text
make_digit:
	cmp eax, '0'
	jl make_symbol
	cmp eax, '9'
	jg make_symbol
	sub eax, '0'
	lea esi, digits
	jmp draw_text
make_symbol:
	cmp eax, '"'
	jl make_space
	cmp eax, '/'
	jg make_space
	sub eax, '"'
	lea esi, symbols
	jmp draw_text
	; CE -> "
	; = -> ,
	; radical -> )
	; x^2 -> (
	; 1/x -> '
	; backspace -> &
	; C -> #
	; +/- -> $
make_space:	
	mov eax, 26 ; de la 0 pana la 25 sunt litere, 26 e space
	lea esi, letters
	
draw_text:
	mov ebx, symbol_width
	mul ebx
	mov ebx, symbol_height
	mul ebx
	add esi, eax
	mov ecx, symbol_height
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, symbol_height
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, symbol_width
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_alb
	mov dword ptr [edi], 0
	jmp simbol_pixel_next
simbol_pixel_alb:
	mov dword ptr [edi], 0D3D3D3h
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	popa
	mov esp, ebp
	pop ebp
	ret
make_text endp

; un macro ca sa apelam mai usor desenarea simbolului
make_text_macro macro symbol, drawArea, x, y
	push y
	push x
	push drawArea
	push symbol
	call make_text
	add esp, 16
endm

line_horizontal macro x, y, len, color
local bucla_line
	mov eax, y ;EAX = y
	mov ebx, area_width
	mul ebx ; EAX = y * area_width
	add eax, x ; EAX = y * area_width *x
	shl eax, 2 ; EAX = (y * area_width * x) * 4
	add eax, area
	mov ecx, len
bucla_line:
	mov dword ptr[eax], color
	add eax, 4
	loop bucla_line
endm

line_vertical macro x, y, len, color
local bucla_line
	mov eax, y ;EAX = y
	mov ebx, area_width
	mul ebx ; EAX = y * area_width
	add eax, x ; EAX = y * area_width *x
	shl eax, 2 ; EAX = (y * area_width * x) * 4
	add eax, area
	mov ecx, len
bucla_line:
	mov dword ptr[eax], color
	add eax, area_width * 4
	loop bucla_line
endm

make_button macro x, y, z, color
	line_horizontal x, y, button_size, color
	line_horizontal x, y+button_size-1, button_size, color
	line_vertical x, y, button_size, color
	line_vertical x+button_size-1, y, button_size, color
	make_text_macro z, area, x+25, y+20
endm

get_button macro x1, x2, valoare,caracter
local buton, termen2local, make_numberlocal, skip_inmultirelocal, termen2_finallocal, final_butonlocal, urm_button 
buton:
	;verificam daca ne aflam in perimetrul butonului
	cmp ebx, x1
	jl urm_button
	cmp ebx, x2
	jg urm_button
	;incrementam pozitia de afisare pe ecran
	inc counter_cifre
	mov eax, counter_cifre
	mul zece
	add eax, 8
	mov val_counter, eax
	;decidem daca e primul sau al doilea termen si formam numarul
	cmp pressed_symbol, 0
	jne termen2local
	mov eax, primul_termen
	jmp make_numberlocal
termen2local:
	mov eax, al_doilea_termen
make_numberlocal:
	cmp counter_cifre, 0
	je skip_inmultirelocal
	mul zece
skip_inmultirelocal:
	add eax, valoare
	cmp pressed_symbol, 0
	jne termen2_finallocal
	mov primul_termen, eax
	jmp final_butonlocal
termen2_finallocal:
	mov al_doilea_termen, eax
final_butonlocal:
	make_text_macro caracter, area, val_counter, 28
	push primul_termen
	push al_doilea_termen
	push offset format
	call printf
	add esp, 12
urm_button:
endm

	

; functia de desenare - se apeleaza la fiecare click
; sau la fiecare interval de 200ms in care nu s-a dat click
; arg1 - evt (0 - initializare, 1 - click, 2 - s-a scurs intervalul fara click)
; arg2 - x
; arg3 - y
draw proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1]
	cmp eax, 1
	jz evt_click
	cmp eax, 2
	jz evt_timer ; nu s-a efectuat click pe nimic
	;mai jos e codul care intializeaza fereastra cu pixeli albi
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 211
	push area
	call memset
	add esp, 12
	jmp afisare_calculator
	
evt_click:
;verificam daca ne aflal la finalul unei foste operatii si curatam ecranul in caz afirmativ
	mov ecx, 24
	cmp finished, 0
	jne reset_ecran_click
	jmp afla_rand
reset_ecran_click:
	mov eax, ecx
	mul zece
	add eax, 8
	mov val_sterse, eax
	make_text_macro " ", area, val_sterse, 28
	loop reset_ecran_click
	mov eax, 0
	mov finished, eax
	mov eax, -1
	mov counter_cifre, eax
	
afla_rand:
mov eax, [ebp+arg3] ; EAX = y
mov ebx, [ebp+arg2] ; EBX = x
cmp eax, 76+button_size+4
jl no_button
jge rand2

rand2:
	cmp eax, 76+button_size+4
	jl no_button
	cmp eax, 76+button_size+4+button_size
	jge rand3
		
buton_impartire:
	cmp ebx, button_size*3+4*4
	jl no_button
	cmp ebx, (button_size+4)*4
	jg no_button
	inc counter_cifre
	mov eax, counter_cifre
	mul zece
	add eax, 8
	mov val_counter, eax
	inc pressed_symbol
	inc pressed_impartire
	make_text_macro '/', area, val_counter, 28
	inc counter_cifre
	mov eax, counter_cifre
	mul zece
	add eax, 8
	mov val_counter, eax
	make_text_macro ' ', area, val_counter, 28

rand3:
	cmp eax, 76+(button_size+4)*2
	jl no_button
	cmp eax, 76+(button_size+4)*2+button_size
	jge rand4
	
	get_button 4, button_size+4, 7, '7'
	get_button button_size+4*2,  (button_size+4)*2, 8, '8'
	get_button button_size*2+4*3, (button_size+4)*3 , 9,'9'
	
buton_inmultire:
cmp ebx, button_size*3+4*4
	jl no_button
	cmp ebx, (button_size+4)*4
	jg no_button
	inc counter_cifre
	mov eax, counter_cifre
	mul zece
	add eax, 8
	mov val_counter, eax
	inc pressed_symbol
	inc pressed_inmultire
	make_text_macro '*', area, val_counter, 28
	inc counter_cifre
	mov eax, counter_cifre
	mul zece
	add eax, 8
	mov val_counter, eax
	make_text_macro ' ', area, val_counter, 28	
	
rand4:
	cmp eax, 76+(button_size+4)*3
	jl no_button
	cmp eax, 76+(button_size+4)*3+button_size
	jge rand5
	
	get_button 4, button_size+4, 4, '4'
	get_button button_size+4*2,  (button_size+4)*2, 5, '5'
	get_button button_size*2+4*3, (button_size+4)*3, 6, '6'
	
buton_minus:
	cmp ebx, button_size*3+4*4
	jl no_button
	cmp ebx, (button_size+4)*4
	jg no_button
	inc counter_cifre
	mov eax, counter_cifre
	mul zece
	add eax, 8
	mov val_counter, eax
	inc pressed_symbol
	inc pressed_minus
	make_text_macro '-', area, val_counter, 28
	inc counter_cifre
	mov eax, counter_cifre
	mul zece
	add eax, 8
	mov val_counter, eax
	make_text_macro ' ', area, val_counter, 28
	
rand5:
	cmp eax, 76+(button_size+4)*4
	jl no_button
	cmp eax, 76+(button_size+4)*4+button_size
	jge rand6
	
	get_button 4, button_size+4, 1, '1'
	get_button button_size+4*2,  (button_size+4)*2, 2, '2'
	get_button button_size*2+4*3, (button_size+4)*3, 3, '3'
	
buton_plus:
	cmp ebx, button_size*3+4*4
	jl no_button
	cmp ebx, (button_size+4)*4
	jg no_button
	inc counter_cifre
	mov eax, counter_cifre
	mul zece
	add eax, 8
	mov val_counter, eax
	inc pressed_symbol
	inc pressed_plus
	make_text_macro '+', area, val_counter, 28
	inc counter_cifre
	mov eax, counter_cifre
	mul zece
	add eax, 8
	mov val_counter, eax
	make_text_macro ' ', area, val_counter, 28
	
rand6:
	cmp eax, 76+(button_size+4)*5
	jl no_button
	cmp eax, 76+(button_size+4)*5+button_size
	jge no_button
	
buton_schimba_simbol:
	cmp ebx, 4
	jl no_button
	cmp ebx, button_size+4
	jg final_semn; buton_zero
		
	;verificam daca schimbam simbolul pentru primul sau al doilea termen
	cmp pressed_symbol, 0
	jne pt_al_doilea
pt_primul:
	inc counter_cifre
	;daca changed_sign este divizibil cu 2, semnul este + si nu se afiseaza, iar acesta este - in caz contrar
	inc changed_sign1
	mov eax, changed_sign1
	div doi
	cmp ah, 0
	jne este_minus
	
	dec counter_cifre
	mov eax, counter_cifre
	mul zece
	add eax, 8
	mov val_counter, eax
	make_text_macro ' ', area, val_counter, 28
	dec counter_cifre
	jmp final_semn
este_minus:
	mov eax, counter_cifre
	mul zece
	add eax, 8
	mov val_counter, eax
	make_text_macro '-', area, val_counter, 28 
	jmp final_semn

pt_al_doilea:
	inc counter_cifre
	inc changed_sign2
	mov eax, changed_sign2
	div doi
	cmp ah, 0
	jne este_minus2
	
	dec counter_cifre
	mov eax, counter_cifre
	mul zece
	add eax, 8
	mov val_counter, eax
	make_text_macro ' ', area, val_counter, 28
	dec counter_cifre
	jmp final_semn
este_minus2:
	mov eax, counter_cifre
	mul zece
	add eax, 8
	mov val_counter, eax
	make_text_macro '-', area, val_counter, 28 
	jmp final_semn
final_semn:	

	get_button button_size+4*2,  (button_size+4)*2, 0, '0'
	

buton_egal:
	cmp ebx, button_size*3+4*4
	jl no_button
	cmp ebx, (button_size+4)*4
	jg no_button
	inc counter_cifre
	
reset_ecran:
	mov eax, cifre_sterse
	mul zece
	add eax, 8
	mov val_sterse, eax
	make_text_macro " ", area, val_sterse, 28
	inc cifre_sterse
	mov ebx, cifre_sterse
	mov eax, counter_cifre
	cmp eax, ebx
	jne reset_ecran
	
	;verificam semnul si negam termenii daca acesta este -
	mov eax, changed_sign1
	div doi
	cmp ah, 0
	jne neaga_primul
	jmp test_neaga_al_doilea
neaga_primul:
	mov eax, primul_termen
	neg eax
	mov primul_termen, eax
	
test_neaga_al_doilea:
	mov eax, changed_sign2
	div doi
	cmp ah, 0
	je afla_operatia

neaga_al_doilea:
	mov eax, al_doilea_termen
	neg eax
	mov al_doilea_termen, eax

afla_operatia:	
	
	cmp pressed_plus, 0
	jne adunare
	cmp pressed_minus, 0
	jne scadere
	cmp pressed_inmultire, 0
	jne inmultire
	cmp pressed_impartire, 0
	jne impartire
	
adunare:
	mov edx, 0
	mov eax, primul_termen
	add eax, al_doilea_termen
	adc edx, 0
	mov rezultat_up, edx
	mov rezultat_down, eax
	jmp afisare_rezultat
		
scadere:
	mov edx, 0
	mov eax, primul_termen
	sub eax, al_doilea_termen
	sbb edx, 0
	mov rezultat_up, edx
	mov rezultat_down, eax
	jmp afisare_rezultat
	
inmultire:
	mov eax, primul_termen
	imul eax, al_doilea_termen
	mov rezultat_up, edx
	mov rezultat_down, eax
	jmp afisare_rezultat
	

impartire:
	mov eax, primul_termen
	idiv al_doilea_termen
	mov rezultat_up, edx
	mov rezultat_down, eax
	jmp afisare_rezultat
	
afisare_rezultat:
	;realizam conversia de la numar la string pentru afisare
	mov eax, rezultat_down
	mov ecx, 10
	mov ebx, 0 ; ebx este counter pentru numarul de push-uri
	cmp eax, -1
	jng dubla_negare
	jmp divide
dubla_negare:
	neg eax
	make_text_macro '-', area, 8, 28
	
	
divide:
	mov edx, 0
	div ecx
	push edx ; DL este o cifra in intervalul [0, 9]
	inc ebx ; incrementeaza counter-ul
	test eax, eax ; verificam daca eax este 0
	jnz divide
	; facem pop cu EBX ca si counter
	mov ecx, ebx
	lea esi, str_rezultat ; esi este pointer spre string

get_digit:
	pop eax
	add al, '0' ; obtinem codul ASCII al cifrei
	;salvam in string
	mov [esi], al
	inc esi
	loop get_digit
	
	mov esi, 0
bucla_afisare:
	cmp str_rezultat[esi], 0
	je verificare_existenta_rest;final_bucla_afisare
	mov eax, 0
	mov al, str_rezultat[esi]
	mov ebx, eax
	mov eax, esi
	mul zece
	add eax, 18
	mov val_rezultat, eax
	make_text_macro ebx, area, val_rezultat, 28
	mov eax, ebx
	inc esi
	jmp bucla_afisare
	
verificare_existenta_rest:
	push rezultat_up
	push offset format3
	call printf
	add esp, 8
	
	cmp pressed_impartire, 0
	je final_bucla_afisare
	cmp rezultat_up, 0
	je final_bucla_afisare
	
	mov eax, counter_cifre
	mul zece
	add eax, 8
	mov val_rezultat, eax
	make_text_macro '.', area, val_counter, 28
	
	
afisare_rest:
	;realizam conversia de la numar la string pentru afisare
	mov eax, rezultat_up
	mov ecx, 10
	mov ebx, 0 ; ebx este counter pentru numarul de push-uri
	
divide_rest:
	mov edx, 0
	div ecx
	push edx ; DL este o cifra in intervalul [0, 9]
	inc ebx ; incrementeaza counter-ul
	test eax, eax ; verificam daca eax este 0
	jnz divide_rest
	;facem pop cu EBX ca si counter
	mov ecx, ebx
	lea esi, str_rezultat_up ; esi este pointer spre string

get_digit_rest:
	pop eax
	add al, '0' ; obtinem codul ASCII al cifrei
	;salvam in string
	mov [esi], al
	inc esi
	loop get_digit_rest
	
	mov esi, 0
bucla_afisare_rest:
	cmp str_rezultat_up[esi], 0
	je final_bucla_afisare
	mov eax, 0
	mov al, str_rezultat_up[esi]
	mov ebx, eax
	mov eax, counter_cifre
	mul zece
	add eax, 18
	mov val_rezultat, eax
	make_text_macro ebx, area, val_rezultat, 28
	mov eax, ebx
	
	push eax
	push offset format2
	call printf
	add esp, 8
	
	inc esi
	jmp bucla_afisare_rest
	
	

	
final_bucla_afisare:
	inc finished
	mov eax, 0
	mov cifre_sterse, eax
	mov primul_termen, eax
	mov al_doilea_termen, eax
	mov rezultat_up, eax
	mov rezultat_down, eax
	mov pressed_symbol, eax
	mov pressed_plus, eax
	mov pressed_minus, eax
	mov pressed_inmultire, eax
	mov pressed_impartire, eax
	mov changed_sign1, eax
	mov changed_sign2, eax
	mov val_rezultat, eax
	mov ecx, 32
	lea esi, str_rezultat
reset_string:
	mov [esi],eax
	inc esi
	loop reset_string
	mov eax, 0
	mov ebx, 0
	mov ecx, 0
	mov edx, 0
	mov esi, 0
	
	

no_button:
	jmp afisare_calculator
	
evt_timer:
	inc counter
	
afisare_calculator:
	;desenam chenarul ce inconjoara calculatorul
	line_horizontal 0, 0, area_width, 0h
	line_horizontal 0, 459, area_width, 0h
	line_vertical 0, 0, area_height, 0h
	line_vertical 259, 0, area_height, 0h
	;desenam casuta in care se afiseaza
	line_horizontal 4, 8, 252, 1E88E5h
	line_horizontal 4, 68, 252, 1E88E5h
	line_vertical 4, 8, 60, 1E88E5h
	line_vertical 256, 8, 60, 1E88E5h
	;primul rand de butoane
	make_button 4, 76, '%', 0DCDCDCh
	make_button button_size+4*2, 76, '"', 0DCDCDCh ;CE
	make_button button_size*2+4*3, 76, '#', 0DCDCDCh ;C
	make_button button_size*3+4*4, 76, '&', 0DCDCDCh ;backspace
	;al doilea rand de butoane
	make_button 4, 76+button_size+4, '''', 0DCDCDCh ;1/x
	make_button button_size+4*2, 76+button_size+4, '(',0DCDCDCh ; x^2
	make_button button_size*2+4*3, 76+button_size+4, ')', 0DCDCDCh ; radical de ordin 2 
	make_button button_size*3+4*4, 76+button_size+4, '/', 0DCDCDCh
	;al treilea rand de butoane
	make_button 4, 76+(button_size+4)*2, '7', 0FFFFFFh
	make_button button_size+4*2, 76+(button_size+4)*2, '8', 0FFFFFFh
	make_button button_size*2+4*3, 76+(button_size+4)*2, '9', 0FFFFFFh
	make_button button_size*3+4*4, 76+(button_size+4)*2, '*', 0DCDCDCh
	;al patrulea rand de butoane
	make_button 4, 76+(button_size+4)*3, '4', 0FFFFFFh
	make_button button_size+4*2, 76+(button_size+4)*3, '5', 0FFFFFFh
	make_button button_size*2+4*3, 76+(button_size+4)*3, '6', 0FFFFFFh
	make_button button_size*3+4*4, 76+(button_size+4)*3, '-', 0DCDCDCh
	;al cincilea rand de butoane
	make_button 4, 76+(button_size+4)*4, '1', 0FFFFFFh
	make_button button_size+4*2, 76+(button_size+4)*4, '2', 0FFFFFFh
	make_button button_size*2+4*3, 76+(button_size+4)*4, '3', 0FFFFFFh
	make_button button_size*3+4*4, 76+(button_size+4)*4, '+', 0DCDCDCh
	;ultimul rand de butoane
	make_button 4, 76+(button_size+4)*5, '$', 0FFFFFFh ; +/-
	make_button button_size+4*2, 76+(button_size+4)*5, '0', 0FFFFFFh
	make_button button_size*2+4*3, 76+(button_size+4)*5, '.', 0FFFFFFh
	make_button button_size*3+4*4, 76+(button_size+4)*5, ',', 1E88E5h ; egal

	
final_draw:
	popa
	mov esp, ebp
	pop ebp
	ret
draw endp

start:
	;alocam memorie pentru zona de desenat
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov area, eax
	;apelam functia de desenare a ferestrei
	; typedef void (*DrawFunc)(int evt, int x, int y);
	; void __cdecl BeginDrawing(const char *title, int width, int height, unsigned int *area, DrawFunc draw);
	push offset draw
	push area
	push area_height
	push area_width
	push offset window_title
	call BeginDrawing
	add esp, 20

	
	;terminarea programului
	push 0
	call exit
end start
