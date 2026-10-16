# Reguły R8 dla wydania.
#
# Wtyczka `google_mlkit_text_recognition` odwołuje się do rozpoznawania
# pisma chińskiego, japońskiego, koreańskiego i dewanagari. Aplikacja czyta
# polskie etykiety środków, więc tych bibliotek nie dołączamy — bez tych
# reguł R8 przerywa budowanie wydania („Missing classes detected while
# running R8"). To nie jest obejście błędu CI: `flutter build apk --release`
# wywala się tak samo na komputerze.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
