local RT = AutoCallboardRuntime

RT.api:Problems("ACB", {
  ["LIST.CONTAINER_FULL"] = { class = "refus" },
  ["LIST.GROUPS_FULL"] = { class = "refus" },
  ["LIST.SELECTION_CHANGE_REFUSED"] = { class = "echec", key = "action" },
  ["LIST.GROUP_CHANGE_REFUSED"] = { class = "echec", key = "action" },
  ["QUESTDATA.IMPORT_EMPTY"] = { class = "echec" },
  ["QUESTDATA.IMPORT_NO_MARKER"] = { class = "echec" },
  ["QUESTDATA.IMPORT_NO_VALID_LINE"] = { class = "echec" },
  ["QUESTDATA.IMPORT_PARTIAL"] = { class = "partiel" },
})

EbonAPI.Locale.register("AutoCallboard", {
  enUS = {
    PROBLEM_LIST_CONTAINER_FULL = "this container already holds {limit} collections, which is the maximum. Nothing was added; delete a collection first",
    PROBLEM_LIST_GROUPS_FULL = "you already have {limit} groups, which is the maximum. No group was created; delete a group first",
    PROBLEM_LIST_SELECTION_CHANGE_REFUSED = "the change to the list {list} was refused: the list was not found or is no longer valid. Nothing was changed; reopen the lists window and try again",
    PROBLEM_LIST_GROUP_CHANGE_REFUSED = "the change to the group {group} was refused: the group was not found or is no longer valid. Nothing was changed; reopen the lists window and try again",
    PROBLEM_QUESTDATA_IMPORT_EMPTY = "nothing was imported because the text is empty ({preview}). Paste the exported quest data, then import again",
    PROBLEM_QUESTDATA_IMPORT_NO_MARKER = "nothing was imported because the text does not start with the quest data marker ({preview}). Paste the full text exported by AutoCallboard",
    PROBLEM_QUESTDATA_IMPORT_NO_VALID_LINE = "nothing was imported because none of the lines could be read ({skipped} skipped, first line: {preview}). Check that the text was copied completely",
    PROBLEM_QUESTDATA_IMPORT_PARTIAL = "{imported} quests were imported but {skipped} lines could not be read and were skipped. Check that the text was copied completely",
    QUESTDATA_IMPORTED = "Quest data imported: %d quests read, %d known in total.",
  },
  frFR = {
    PROBLEM_LIST_CONTAINER_FULL = "ce conteneur contient déjà {limit} collections, ce qui est le maximum. Rien n'a été ajouté ; supprimez d'abord une collection",
    PROBLEM_LIST_GROUPS_FULL = "vous avez déjà {limit} groupes, ce qui est le maximum. Aucun groupe n'a été créé ; supprimez d'abord un groupe",
    PROBLEM_LIST_SELECTION_CHANGE_REFUSED = "la modification de la liste {list} a été refusée : la liste est introuvable ou n'est plus valide. Rien n'a été modifié ; rouvrez la fenêtre des listes et réessayez",
    PROBLEM_LIST_GROUP_CHANGE_REFUSED = "la modification du groupe {group} a été refusée : le groupe est introuvable ou n'est plus valide. Rien n'a été modifié ; rouvrez la fenêtre des listes et réessayez",
    PROBLEM_QUESTDATA_IMPORT_EMPTY = "rien n'a été importé car le texte est vide ({preview}). Collez les données de quêtes exportées, puis importez de nouveau",
    PROBLEM_QUESTDATA_IMPORT_NO_MARKER = "rien n'a été importé car le texte ne commence pas par le marqueur des données de quêtes ({preview}). Collez le texte complet exporté par AutoCallboard",
    PROBLEM_QUESTDATA_IMPORT_NO_VALID_LINE = "rien n'a été importé car aucune ligne n'a pu être lue ({skipped} ignorées, première ligne : {preview}). Vérifiez que le texte a été copié en entier",
    PROBLEM_QUESTDATA_IMPORT_PARTIAL = "{imported} quêtes ont été importées mais {skipped} lignes n'ont pas pu être lues et ont été ignorées. Vérifiez que le texte a été copié en entier",
    QUESTDATA_IMPORTED = "Données de quêtes importées : %d quêtes lues, %d connues au total.",
  },
  deDE = {
    PROBLEM_LIST_CONTAINER_FULL = "dieser Container enthält bereits {limit} Sammlungen, das ist das Maximum. Es wurde nichts hinzugefügt; löschen Sie zuerst eine Sammlung",
    PROBLEM_LIST_GROUPS_FULL = "Sie haben bereits {limit} Gruppen, das ist das Maximum. Es wurde keine Gruppe erstellt; löschen Sie zuerst eine Gruppe",
    PROBLEM_LIST_SELECTION_CHANGE_REFUSED = "die Änderung der Liste {list} wurde abgelehnt: die Liste wurde nicht gefunden oder ist nicht mehr gültig. Es wurde nichts geändert; öffnen Sie das Listenfenster neu und versuchen Sie es erneut",
    PROBLEM_LIST_GROUP_CHANGE_REFUSED = "die Änderung der Gruppe {group} wurde abgelehnt: die Gruppe wurde nicht gefunden oder ist nicht mehr gültig. Es wurde nichts geändert; öffnen Sie das Listenfenster neu und versuchen Sie es erneut",
    PROBLEM_QUESTDATA_IMPORT_EMPTY = "es wurde nichts importiert, weil der Text leer ist ({preview}). Fügen Sie die exportierten Questdaten ein und importieren Sie erneut",
    PROBLEM_QUESTDATA_IMPORT_NO_MARKER = "es wurde nichts importiert, weil der Text nicht mit der Markierung der Questdaten beginnt ({preview}). Fügen Sie den vollständigen von AutoCallboard exportierten Text ein",
    PROBLEM_QUESTDATA_IMPORT_NO_VALID_LINE = "es wurde nichts importiert, weil keine Zeile gelesen werden konnte ({skipped} übersprungen, erste Zeile: {preview}). Prüfen Sie, ob der Text vollständig kopiert wurde",
    PROBLEM_QUESTDATA_IMPORT_PARTIAL = "{imported} Quests wurden importiert, aber {skipped} Zeilen konnten nicht gelesen werden und wurden übersprungen. Prüfen Sie, ob der Text vollständig kopiert wurde",
    QUESTDATA_IMPORTED = "Questdaten importiert: %d Quests gelesen, %d insgesamt bekannt.",
  },
  esES = {
    PROBLEM_LIST_CONTAINER_FULL = "este contenedor ya contiene {limit} colecciones, que es el máximo. No se añadió nada; elimine primero una colección",
    PROBLEM_LIST_GROUPS_FULL = "ya tiene {limit} grupos, que es el máximo. No se creó ningún grupo; elimine primero un grupo",
    PROBLEM_LIST_SELECTION_CHANGE_REFUSED = "se rechazó el cambio de la lista {list}: la lista no se encontró o ya no es válida. No se cambió nada; vuelva a abrir la ventana de listas e inténtelo de nuevo",
    PROBLEM_LIST_GROUP_CHANGE_REFUSED = "se rechazó el cambio del grupo {group}: el grupo no se encontró o ya no es válido. No se cambió nada; vuelva a abrir la ventana de listas e inténtelo de nuevo",
    PROBLEM_QUESTDATA_IMPORT_EMPTY = "no se importó nada porque el texto está vacío ({preview}). Pegue los datos de misiones exportados y vuelva a importar",
    PROBLEM_QUESTDATA_IMPORT_NO_MARKER = "no se importó nada porque el texto no empieza con la marca de los datos de misiones ({preview}). Pegue el texto completo exportado por AutoCallboard",
    PROBLEM_QUESTDATA_IMPORT_NO_VALID_LINE = "no se importó nada porque no se pudo leer ninguna línea ({skipped} omitidas, primera línea: {preview}). Compruebe que el texto se copió completo",
    PROBLEM_QUESTDATA_IMPORT_PARTIAL = "se importaron {imported} misiones pero {skipped} líneas no se pudieron leer y se omitieron. Compruebe que el texto se copió completo",
    QUESTDATA_IMPORTED = "Datos de misiones importados: %d misiones leídas, %d conocidas en total.",
  },
})
