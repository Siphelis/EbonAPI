local RT = AutoCallboardRuntime

RT.api:Problems("ACB", {
  ["INSTANCE.MAP_UNAVAILABLE"] = { class = "partiel" },
})

EbonAPI.Locale.register("AutoCallboard", {
  enUS = {
    PROBLEM_INSTANCE_MAP_UNAVAILABLE = "the game gave no map name for this instance after {attempts} attempts, so its quest cannot be targeted automatically. Choose the quest yourself in the list, or leave and re-enter the instance to try again",
  },
  frFR = {
    PROBLEM_INSTANCE_MAP_UNAVAILABLE = "le jeu n'a donné aucun nom de carte pour cette instance après {attempts} essais, donc sa quête ne peut pas être ciblée automatiquement. Choisissez la quête vous-même dans la liste, ou sortez de l'instance et rentrez-y pour réessayer",
  },
  deDE = {
    PROBLEM_INSTANCE_MAP_UNAVAILABLE = "das Spiel hat nach {attempts} Versuchen keinen Kartennamen für diese Instanz geliefert, daher kann ihre Quest nicht automatisch gewählt werden. Wählen Sie die Quest selbst in der Liste, oder verlassen Sie die Instanz und betreten Sie sie erneut",
  },
  esES = {
    PROBLEM_INSTANCE_MAP_UNAVAILABLE = "el juego no dio ningún nombre de mapa para esta instancia tras {attempts} intentos, así que su misión no se puede elegir automáticamente. Elija usted mismo la misión en la lista, o salga de la instancia y vuelva a entrar",
  },
})
