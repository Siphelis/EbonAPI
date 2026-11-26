local RT = AutoCallboardRuntime

RT.api:Problems("ACB", {
  ["ROUTEWINDOW.DRAFT_EMPTY"] = { class = "refus" },
  ["ROUTEWINDOW.ROUTES_FULL"] = { class = "refus", key = "category" },
  ["ROUTEWINDOW.ROUTE_MISSING"] = { class = "echec", key = "route" },
  ["ROUTEWINDOW.CHANGE_REFUSED"] = { class = "echec", key = "action" },
  ["ROUTEWINDOW.EDIT_LOCKED"] = { class = "refus" },
})

EbonAPI.Locale.register("AutoCallboard", {
  enUS = {
    PROBLEM_ROUTEWINDOW_DRAFT_EMPTY = "the route was not saved because the recording holds no step. Nothing was changed; record at least one step, then save again",
    PROBLEM_ROUTEWINDOW_ROUTES_FULL = "the route could not go into the category \"{category}\" because it already holds {limit} routes. The route stays where it was; delete a route from that category or choose another one",
    PROBLEM_ROUTEWINDOW_ROUTE_MISSING = "the route \"{route}\" no longer exists, so the change was not made. The list is refreshed; choose a route that is still there",
    PROBLEM_ROUTEWINDOW_CHANGE_REFUSED = "the change to the route \"{route}\" was refused and nothing was modified. Check that the route is still in the list and try again",
    PROBLEM_ROUTEWINDOW_EDIT_LOCKED = "the route \"{route}\" cannot be changed or loaded while a route is being played. Nothing was changed; stop the playback first",
  },
  frFR = {
    PROBLEM_ROUTEWINDOW_DRAFT_EMPTY = "le parcours n'a pas été enregistré car l'enregistrement ne contient aucune étape. Rien n'a été modifié ; enregistrez au moins une étape, puis recommencez",
    PROBLEM_ROUTEWINDOW_ROUTES_FULL = "le parcours n'a pas pu aller dans la catégorie « {category} » car elle contient déjà {limit} parcours. Le parcours reste où il était ; supprimez un parcours de cette catégorie ou choisissez-en une autre",
    PROBLEM_ROUTEWINDOW_ROUTE_MISSING = "le parcours « {route} » n'existe plus, donc la modification n'a pas été faite. La liste est actualisée ; choisissez un parcours encore présent",
    PROBLEM_ROUTEWINDOW_CHANGE_REFUSED = "la modification du parcours « {route} » a été refusée et rien n'a été changé. Vérifiez que le parcours est toujours dans la liste, puis réessayez",
    PROBLEM_ROUTEWINDOW_EDIT_LOCKED = "le parcours « {route} » ne peut pas être modifié ni chargé pendant la lecture d'un parcours. Rien n'a été changé ; arrêtez d'abord la lecture",
  },
  deDE = {
    PROBLEM_ROUTEWINDOW_DRAFT_EMPTY = "die Route wurde nicht gespeichert, weil die Aufnahme keinen Schritt enthält. Es wurde nichts geändert; nehmen Sie mindestens einen Schritt auf und speichern Sie dann erneut",
    PROBLEM_ROUTEWINDOW_ROUTES_FULL = "die Route konnte nicht in die Kategorie \"{category}\" verschoben werden, weil sie bereits {limit} Routen enthält. Die Route bleibt, wo sie war; löschen Sie eine Route aus dieser Kategorie oder wählen Sie eine andere",
    PROBLEM_ROUTEWINDOW_ROUTE_MISSING = "die Route \"{route}\" existiert nicht mehr, daher wurde die Änderung nicht vorgenommen. Die Liste wurde aktualisiert; wählen Sie eine noch vorhandene Route",
    PROBLEM_ROUTEWINDOW_CHANGE_REFUSED = "die Änderung der Route \"{route}\" wurde abgelehnt und nichts wurde verändert. Prüfen Sie, ob die Route noch in der Liste steht, und versuchen Sie es erneut",
    PROBLEM_ROUTEWINDOW_EDIT_LOCKED = "die Route \"{route}\" kann während der Wiedergabe einer Route weder geändert noch geladen werden. Es wurde nichts geändert; beenden Sie zuerst die Wiedergabe",
  },
  esES = {
    PROBLEM_ROUTEWINDOW_DRAFT_EMPTY = "la ruta no se guardó porque la grabación no contiene ningún paso. No se cambió nada; grabe al menos un paso y vuelva a guardar",
    PROBLEM_ROUTEWINDOW_ROUTES_FULL = "la ruta no pudo pasar a la categoría \"{category}\" porque ya contiene {limit} rutas. La ruta se queda donde estaba; elimine una ruta de esa categoría o elija otra",
    PROBLEM_ROUTEWINDOW_ROUTE_MISSING = "la ruta \"{route}\" ya no existe, así que no se hizo el cambio. La lista se ha actualizado; elija una ruta que siga presente",
    PROBLEM_ROUTEWINDOW_CHANGE_REFUSED = "se rechazó el cambio de la ruta \"{route}\" y no se modificó nada. Compruebe que la ruta sigue en la lista e inténtelo de nuevo",
    PROBLEM_ROUTEWINDOW_EDIT_LOCKED = "la ruta \"{route}\" no se puede modificar ni cargar mientras se reproduce una ruta. No se cambió nada; detenga primero la reproducción",
  },
})
