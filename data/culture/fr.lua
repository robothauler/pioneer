-- Copyright © 2008-2025 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

local CultureName = require './common'

local male = {
	'Adrien',
	'André',
	'Anselme',
	'Aristide',
	'Arnaud',
	'Arthur',
	'Aubin',
	'Auguste',
	'Aurélien',
	'Baptiste',
	'Barthélémy',
	'Bastien',
	'Baudouin',
	'Benoît',
	'Brice',
	'Charles-Antoine',
	'Chrétien',
	'Clair',
	'Clément',
	'Corentin',
	'Côme',
	'Cyriaque',
	'Damien',
	'Dany',
	'Denis',
	'Didier',
	'Donatien',
	'Édouard',
	'Élias',
	'Éliot',
	'Émerick',
	'Fabien',
	'Fernand',
	'Firmin',
	'Florent',
	'Foudil',
	'François',
	'Frédérick',
	'Félix',
	'Gabriel',
	'Gaspard',
	'Gatien',
	'Gautier',
	'Geoffroy',
	'Ghislain',
	'Giles',
	'Giraud',
	'Guillaume',
	'Gérard',
	'Henri',
	'Hervé',
	'Honoré',
	'Hugues',
	'Iréne',
	'Ismaël',
	'Jacques-Yves',
	'Jean-Albert',
	'Jean-Baptise',
	'Jean-Claude',
	'Jean-Didier',
	'Jean-Guy',
	'Jean-Luc',
	'Jean-Sébastien',
	'Jean-Xavier',
	'Jourdain',
	'Julien',
	'Justin',
	'Jérémi',
	'Jérémy',
	'Lazare',
	'Luc',
	'Ludovic',
	'Léo',
	'Léonard',
	'Marc-Alexandre',
	'Marc-Antoine',
	'Marcellin',
	'Mathieu',
	'Mattéo',
	'Maurice',
	'Maxime',
	'Maël',
	'Michel',
	'Noël',
	'Octavien',
	'Olivier',
	'Patric',
	'Philippe',
	'Pierre',
	'Pierre-Luc',
	'Pierrick',
	'Rafaël',
	'Raphaël',
	'Raymond',
	'Renald',
	'Régis',
	'Rémi',
	'Samuel',
	'Samy',
	'Serge',
	'Simeon',
	'Sofiane',
	'Stefan-André',
	'Stéphane',
	'Sylvain',
	'Tancrede',
	'Thibault',
	'Thierry',
	'Théo',
	'Théophile',
	'Timothé',
	'Virgile',
	'Xavier',
	'Yanick',
	'Yoan',
	'Yves',
	'Zacharie',
	'Èdouard',
	'Èlias',
	'Èliot',
	'Èmerick',
}

local female = {
	'Adéle',
	'Agathe',
	'Aimée',
	'Albane',
	'Alexandra',
	'Amandine',
	'Amée',
	'Anabelle',
	'Anaïs',
	'Andréa',
	'Ange',
	'Annabelle',
	'Anne-Sophie',
	'Annick',
	'Appoline',
	'Arielle',
	'Armelle',
	'Aubine',
	'Bernice',
	'Blanche',
	'Bluette',
	'Camille',
	'Carolane',
	'Caroline',
	'Cerise',
	'Chantal',
	'Charlotte',
	'Claudie',
	'Clervie',
	'Clothilde',
	'Clémence',
	'Colette',
	'Colombe',
	'Coralie',
	'Corentine',
	'Cornélie',
	'Crescence',
	'Cécilie',
	'Célia',
	'Daphné',
	'Delphine',
	'Dominique',
	'Eloise',
	'Emmanuelle',
	'Ernestine',
	'Estée',
	'Eugénie',
	'Evangeline',
	'Fanette',
	'Fantine',
	'Fleur',
	'Florie',
	'Françoise',
	'Gabrielle',
	'Georgette',
	'Germaine',
	'Ghislaine',
	'Giséle',
	'Guenaëlle',
	'Héloïse',
	'Hyacinthe',
	'Iréne',
	'Isabeau',
	'Jeanne-Yvette',
	'Jenevieve',
	'Josette',
	'Juliette',
	'Karine',
	'Laure',
	'Lianne',
	'Lilianne',
	'Lucille',
	'Ludivine',
	'Léa',
	'Léonore',
	'Mabelle',
	'Maelle',
	'Manon',
	'Margaux',
	'Marguerite',
	'Marie',
	'Marie-Claire',
	'Marie-Pier',
	'Marie-Sophie',
	'Mirabelle',
	'Monette',
	'Morgane',
	'Myléne',
	'Mégane',
	'Mélodie',
	'Nadége',
	'Nicolette',
	'Noemi',
	'Océane',
	'Odile',
	'Ondine',
	'Orégane',
	'Paulette',
	'Philippine',
	'Rachelle',
	'Renée',
	'Romaine',
	'Rosalie',
	'Solange',
	'Solenne',
	'Sylvie',
	'Tiphaine',
	'Valérie',
	'Victoire',
	'Virgie',
	'Vivienne',
	'Yvette',
	'Zoë',
	'Èlizabeth',
	'Èléanore',
	'Èmilie',
}

local surname = {
	'Adam',
	'Andre',
	'Arnaud',
	'Aubert',
	'Barbier',
	'Berger',
	'Bernard',
	'Bertrand',
	'Blanc',
	'Blanchard',
	'Bonnet',
	'Bourgeois',
	'Boyer',
	'Brun',
	'Brunet',
	'Caron',
	'Carpentier',
	'Charles',
	'Chevalier',
	'Clement',
	'Colin',
	'David',
	'Denis',
	'Deschamps',
	'Dubois',
	'Dufour',
	'Dumas',
	'Dumont',
	'Dupont',
	'Dupuis',
	'Durand',
	'Duval',
	'Fabre',
	'Faure',
	'Fernandez',
	'Fleury',
	'Fontaine',
	'Fournier',
	'Francois',
	'Gaillard',
	'Garcia',
	'Garnier',
	'Gauthier',
	'Gautier',
	'Gerard',
	'Girard',
	'Giraud',
	'Gonzalez',
	'Guerin',
	'Guillaume',
	'Guillot',
	'Henry',
	'Hubert',
	'Jean',
	'Joly',
	'Lacroix',
	'Lambert',
	'Laurent',
	'Leclerc',
	'Leclercq',
	'Lecomte',
	'Lefebvre',
	'Lefevre',
	'Legrand',
	'Lemaire',
	'Lemoine',
	'Leroux',
	'Leroy',
	'Lopez',
	'Louis',
	'Lucas',
	'Marchand',
	'Marie',
	'Martin',
	'Martinez',
	'Masson',
	'Mathieu',
	'Menard',
	'Mercier',
	'Meunier',
	'Meyer',
	'Michel',
	'Moreau',
	'Morel',
	'Morin',
	'Moulin',
	'Muller',
	'Nguyen',
	'Nicolas',
	'Noel',
	'Olivier',
	'Perez',
	'Perrin',
	'Petit',
	'Philippe',
	'Picard',
	'Pierre',
	'Renard',
	'Renaud',
	'Rey',
	'Richard',
	'Riviere',
	'Robert',
	'Robin',
	'Roche',
	'Rodriguez',
	'Roger',
	'Rolland',
	'Rousseau',
	'Roussel',
	'Roux',
	'Roy',
	'Sanchez',
	'Schmitt',
	'Simon',
	'Thomas',
	'Vidal',
	'Vincent',
}

local French = CultureName.New({
	male = male,
	female = female,
	surname = surname,
	name = "French",
	code = "fr",
	replace = {
		['ë'] = "e", ['Ë'] = "E",
		["é"] = "e", ["É"] = "E",
		['ç'] = 'c', ['Ç'] = 'C',
		['ô'] = 'o', ['Ô'] = 'O',
		['î'] = 'i', ['Î'] = 'I',
	}
})

return French
