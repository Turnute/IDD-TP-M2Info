-- ================================================================================================
-- TP2 IDD
-- Vincent TOURENNE
-- ================================================================================================


-- ================================================================================================
-- EXERCICE A — DÉCOUVERTE DU MODÈLE OBJET-RELATIONNEL
-- Modéliser une bibliothèque : livres, exemplaires, emprunts, personnes et auteurs.
-- ================================================================================================

-- ------------------------------------------------------------------------------------------------
-- NOTIONS DE TYPES ET MÉTHODES
-- ------------------------------------------------------------------------------------------------

-- ------------------------------------------------------------------------------------------------
-- A1 — Créer un type t_personne possédant un nom et un prénom.

CREATE OR REPLACE TYPE t_personne AS OBJECT (
    prenom varchar(20),
    nom varchar(20)
);
/

-- ------------------------------------------------------------------------------------------------
-- A2 — Créer un type t_emprunt possédant un emprunteur (t_personne), une date d'emprunt
-- et un prix à payer par jour.

CREATE OR REPLACE TYPE t_emprunt AS OBJECT (
    emprunteur t_personne,  -- référence à l'emprunteur
    date_emprunt date,      -- date d'emprunt
    prix_jour number(5,2)   -- coût journalier en euros,centimes.
);
/

-- ------------------------------------------------------------------------------------------------
-- A3 — Ajouter à t_emprunt une méthode calculant le prix à payer si le livre était rendu
-- aujourd'hui. La méthode sera testée ultérieurement.

CREATE OR REPLACE TYPE t_emprunt AS OBJECT (
    emprunteur t_personne,  -- référence à l'emprunteur
    date_emprunt date,      -- date d'emprunt
    prix_jour number(5,2),  -- coût journalier en euros,centimes.

    MEMBER FUNCTION cout_tot RETURN NUMBER,    -- renvoie le coût total depuis l'emprunt
    PRAGMA RESTRICT_REFERENCES(cout_tot, WNDS)  -- permet d’utiliser cette méthode dans une requête
);
/


CREATE OR REPLACE TYPE BODY t_emprunt AS
    MEMBER FUNCTION cout_tot RETURN NUMBER IS
        nb_jours NUMBER;
    BEGIN
        nb_jours := CEIL(SYSDATE - date_emprunt);   -- différence arrondie
        RETURN nb_jours * prix_jour;
    END cout_tot;
END;
/


-- ------------------------------------------------------------------------------------------------
-- A4 — Créer un type t_exemplaire possédant un prix et un emprunt.

CREATE OR REPLACE TYPE t_exemplaire AS OBJECT (
    prix number(5,2),
    emprunt t_emprunt
);
/


-- ------------------------------------------------------------------------------------------------
-- NOTIONS DE COLLECTIONS
-- ------------------------------------------------------------------------------------------------

-- ------------------------------------------------------------------------------------------------
-- A5 — Créer une table Livre ayant pour clé primaire un numéro ISBN, et pour attributs
-- un titre et une liste d'exemplaires.

DROP TABLE Livre;
DROP TYPE ex_list;

-- Création du type collection
CREATE TYPE ex_list AS TABLE OF t_exemplaire;
/

-- Création de la table
CREATE TABLE Livre
(
    ISBN INTEGER NOT NULL,
    titre VARCHAR2(50),
    exemplaires ex_list,    -- attribut type_collection
    CONSTRAINT PK_Livre PRIMARY KEY (ISBN)
)
NESTED TABLE exemplaires STORE AS Exemplaire; -- table imbriquée

-- ------------------------------------------------------------------------------------------------
-- A6 — Peupler la table Livre avec quelques livres.

DELETE FROM Livre; -- Vide la table

INSERT INTO Livre (ISBN, titre, exemplaires)
VALUES (
    1,              -- ISBN
    'Le Hobbit',    -- Titre
    ex_list(        -- Liste d'exemplaires
        t_exemplaire(15.50, NULL),          -- coûte 15,5€, n'est pas emprunté
        t_exemplaire(12.00, t_emprunt(      -- coûte 12€, est emprunté...
            t_personne('Jean', 'Dupont'),   -- par Jean Dupont
            SYSDATE - 5,                    -- Il y a 5 jours
            0.50                            -- A un prix journalier de 50 centimes
        ))
    )
);

INSERT INTO Livre (ISBN, titre, exemplaires)
VALUES (
    2,
    'Rhinocéros',
    ex_list(
        t_exemplaire(22.00, NULL),
        t_exemplaire(22.00, t_emprunt(
            t_personne('Marie', 'Martin'),
            SYSDATE - 10,
            1.00
        )),
        t_exemplaire(18.50, NULL)
    )
);

INSERT INTO Livre (ISBN, titre, exemplaires)
VALUES (
    3,
    'Ducobu',
    ex_list(
        t_exemplaire(30.00, t_emprunt(
            t_personne('Lucas', 'Bernard'),
            SYSDATE - 3,
            0.75
        )),
        t_exemplaire(28.00, NULL)
    )
);

SELECT * FROM Livre;

-- Résultat :
-- ISBN TITRE        EXEMPLAIRES                                                                                                                                                                          
-- ---- ------------ ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ 
-- 1    Le Hobbit    [{"prix":15.5,"emprunt":null},{"prix":12,"emprunt":{"emprunteur":{"prenom":"Jean","nom":"Dupont"},"date_emprunt":"2026-10-29T16:27:56Z","prix_jour":0.5}}]                           
-- 2    Rhinocéros   [{"prix":22,"emprunt":null},{"prix":22,"emprunt":{"emprunteur":{"prenom":"Marie","nom":"Martin"},"date_emprunt":"2026-10-24T16:27:56Z","prix_jour":1}},{"prix":18.5,"emprunt":null}] 
-- 3    Ducobu       [{"prix":30,"emprunt":{"emprunteur":{"prenom":"Lucas","nom":"Bernard"},"date_emprunt":"2026-10-31T16:27:56Z","prix_jour":0.75}},{"prix":28,"emprunt":null}]                          


-- ------------------------------------------------------------------------------------------------
-- REQUÊTES RELATIONNELLES-OBJETS
-- ------------------------------------------------------------------------------------------------

-- ------------------------------------------------------------------------------------------------
-- A7 — Calculer le prix moyen des exemplaires du livre d'ISBN 1.

-- Deux livres enregistrés, de prix 15.5 et 12. Moyenne attendue de 13.75.

SELECT SUM(e.prix)/COUNT(*) prix_moyen
FROM Livre l, TABLE(l.exemplaires) e    -- TABLE() permet de désimbriquer la collection !
WHERE ISBN = 1;


-- Résultat :
-- PRIX_MOYEN 
-- ---------- 
-- 13.75      


-- ------------------------------------------------------------------------------------------------
-- A8 — Calculer la somme perçue si tous les exemplaires du livre d'ISBN 1 étaient
-- rendus aujourd'hui.

-- Ne concerne qu'un seul livre (le premier n'est pas emprunté) de coût 12 avec un intérêt de 0.5 
-- par jour, emprunté il y a 5 jours. Somme attendue de 14.5.

SELECT SUM(e.prix+e.emprunt.cout_tot()) somme_tot -- La méthode cout_tot appartient à emprunt.
FROM Livre l, TABLE(l.exemplaires) e
WHERE ISBN = 1;

-- Résultat :
-- SOMME_TOT 
-- --------- 
-- 14.5        

-- On peut tester avec deux livres empruntés. On insère un exemplaire supplémentaire :
INSERT INTO TABLE(
    SELECT l.exemplaires
    FROM Livre l
    WHERE l.ISBN = 1
)
VALUES (
    t_exemplaire(20.00, t_emprunt(
        t_personne('Alice', 'Durand'),
        SYSDATE - 2,
        1.00
    ))
);

-- On vérifie la nouvelle somme (14.5 + (20+1*2) = 36.5) :
SELECT SUM(e.prix + e.emprunt.cout_tot()) somme_tot
FROM Livre l, TABLE(l.exemplaires) e
WHERE l.ISBN = 1;

-- Résultat :
-- SOMME_TOT 
-- --------- 
-- 36.5        


-- ------------------------------------------------------------------------------------------------
-- A9 — Proposer une extension de la base relationnelle-objet couvrant l'ensemble du
-- cahier des charges.

-- Changements à effectuer :
-- 1. Une personne doit avoir une référence vers son père, une autre personne.
-- 2. Création d'un type auteur : personne + si elle a le prix Goncourt ou non.
-- 3. Un livre doit avoir un ou plusieurs auteurs de définis (collection, comme pour les exemplaires).

-- 1. PERSONNE : REFERENCE VERS PERE

-- ALTER plutôt qu'un DROP OR REPLACE : le type t_personne existe déjà et a des dépendances.
ALTER TYPE t_personne
ADD ATTRIBUTE (pere REF t_personne)
CASCADE;
/

-- Besoin d'avoir une table personne pour que pere puisse pointer qq part
CREATE TABLE Personnes OF t_personne;


-- Enregistrement et test
INSERT INTO Personnes VALUES (t_personne('Jean', 'Dupont', NULL));

INSERT INTO Personnes
SELECT t_personne('Jean-Jean', 'Dupont', REF(p))
FROM Personnes p
WHERE p.prenom = 'Jean' AND p.nom = 'Dupont';

SELECT p.prenom, p.nom,
       p.pere.prenom AS prenom_pere,
       p.pere.nom AS nom_pere
FROM Personnes p;


-- Résultat attendu :
-- PRENOM               NOM                  PRENOM_PERE          NOM_PERE            
-- -------------------- -------------------- -------------------- --------------------
-- Jean                 Dupont                                                        
-- Jean-Jean            Dupont               Jean                 Dupont

-- Ajout de personnes qui seront des auteurs
INSERT INTO Personnes VALUES (t_personne('J.R.R', 'Tolkien', NULL));
INSERT INTO Personnes VALUES (t_personne('Moi', 'Même', NULL));

INSERT INTO Personnes
SELECT t_personne('Mon', 'Fils', REF(p))
FROM Personnes p
WHERE p.prenom = 'Moi' AND p.nom = 'Même';


-- 2. TYPE AUTEUR

-- Création du type
CREATE TYPE t_auteur AS OBJECT (
    personne REF t_personne,    -- pointe vers une personne existante
    goncourt CHAR(1)            -- O pour oui, N pour non
);
/


-- 3. AJOUT DU TYPE AUTEUR EN COLLECTION A LA TABLE LIVRE

-- Collection
CREATE TYPE auteur_list AS TABLE OF t_auteur;
/

-- Ajout de la collection à Livre
ALTER TABLE Livre
ADD (auteurs auteur_list)
NESTED TABLE auteurs STORE AS AuteursLivre;
/

-- Trigger sur la table livre, on doit forcément avoir au moins un auteur à l'insertion
-- (On ne gère pas ici les livres exemples déjà insérés)
CREATE OR REPLACE TRIGGER no_empty_auteur
BEFORE INSERT OR UPDATE OF auteurs ON Livre
FOR EACH ROW
DECLARE
    liste auteur_list;
BEGIN
    liste := :NEW.auteurs;
    IF liste IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Le livre doit avoir au moins un auteur !');
    ELSIF liste.COUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Le livre doit avoir au moins un auteur !');
    END IF;
END;
/

-- Test :
-- Update d'un livre existant
-- On récupère une personne de la table personne comme auteur
UPDATE Livre l
SET auteurs = (
    SELECT auteur_list(t_auteur(REF(p), 'N'))
    FROM Personnes p
    WHERE p.prenom = 'J.R.R' AND p.nom = 'Tolkien'
)
WHERE l.ISBN = 1;

-- Insertion d'un livre sans auteur
INSERT INTO Livre (ISBN, titre, exemplaires)
VALUES (
    4,
    'MonLivreAMoi',
    ex_list(
        t_exemplaire(100.00, NULL),
        t_exemplaire(0.00, NULL)
    )
);
-- Erreur SQL : ORA-20001: Le livre inséré doit avoir au moins un auteur !

-- Insertion d'un livre avec plusieurs auteurs
INSERT INTO Livre (ISBN, titre, exemplaires, auteurs)
SELECT 4,
       'MonLivreAMoi',
       ex_list(t_exemplaire(100.00, NULL), t_exemplaire(0.00, NULL)),
       auteur_list(
           t_auteur(REF(p), 'O'),
           t_auteur(REF(f), 'N')
       )
FROM Personnes p, Personnes f
WHERE p.prenom = 'Moi' AND p.nom = 'Même' AND f.prenom = 'Mon' AND f.nom = 'Fils';

SELECT 
    l.ISBN, l.titre,
    a.personne.prenom AS prenom_auteur,
    a.personne.nom AS nom_auteur,
    a.goncourt
FROM Livre l, TABLE(l.auteurs) a;

-- Résultat attendu :
--       ISBN TITRE                                              PRENOM_AUTEUR        NOM_AUTEUR           G
-- ---------- -------------------------------------------------- -------------------- -------------------- -
--          1 Le Hobbit                                          J.R.R                Tolkien              N
--          4 MonLivreAMoi                                       Moi                  Même                 O
--          4 MonLivreAMoi                                       Mon                  Fils                 N


-- ------------------------------------------------------------------------------------------------
-- A10 — Proposer des requêtes montrant l'intérêt de l'extension précédente.

-- Exemple simple : récupérer tous les livres écris par Mon Fils

-- Update simple pour retourner plusieurs livres
UPDATE Livre l
SET auteurs = (
    SELECT auteur_list(t_auteur(REF(f), 'N'))
    FROM Personnes f
    WHERE f.prenom = 'Mon' AND f.nom = 'Fils'
)
WHERE l.ISBN = 3;

-- Requête :
SELECT
    l.ISBN,
    l.titre,
    a.personne.prenom AS prenom_auteur,
    a.personne.nom AS nom_auteur
FROM Livre l, TABLE(l.auteurs) a
WHERE a.personne.prenom = 'Mon' AND a.personne.nom = 'Fils';




-- ================================================================================================
-- EXERCICE B — CONCEPTION D'UNE PLATEFORME DE VOD EN RELATIONNEL-OBJET
-- Modéliser les contenus vidéo, les comptes clients, les achats, les locations
-- et les abonnements à partir du cahier des charges fourni.
-- ================================================================================================

-- ------------------------------------------------------------------------------------------------
-- B1 — Proposer une conception relationnelle-objet pour le cahier des charges VOD.
-- ------------------------------------------------------------------------------------------------


-- On fait un type t_personne(prénom, nom), utile pour un peu tout :)
-- type t_dates(date_debut, date_fin), utile pour location et abonnement

-- On utilise un mécanisme d'héritage pour le contenu :
-- Classe CONTENU de base avec ref(pkey), titre, desc, thème, mots clés (collection varchar), réalisateurs (collection t_personne), année et pays
-- Héritage en :
-- - cinema : duree, acteurs (collection t_personne), scenaristes (collection t_personne)
-- - serie : collection saisons (type t_saison(nb_ep, desc)) + nombre (automatisé par trigger)
-- - jeunesse : duree, scenaristes (collection t_personne), compositeur (collection t_personne)
-- - divertissement : duree, metteurs en scene (collection t_personne), interprètes (collection t_personne)

--  → table Contenu of type t_contenu avec tout ça

-- type t_location(ref id_contenu, t_dates, num_saison_serie (peut être null))
-- Table modèle d'abonnement : duree max d'emprunt pour les 4 types (max_cine, max_series...), nb max total d'emprunts, coût mensuel
-- type t_abonnement(ref id_abonnement, t_dates)

-- Table CompteClient : id (pkey), nom, prenom, adresse, mail, telephone, mdp, contenus achetés (collection t_contenu), contenus loués (collection t_location), abonnement t_abonnement (peut être null)


-- ------------------------------------------------------------------------------------------------
-- B2 — Écrire les requêtes SQL demandées pour la conception proposée en B1.
-- Livrable mentionné dans le sujet : script requete.sql.
-- ------------------------------------------------------------------------------------------------

-- ------------------------------------------------------------------------------------------------
-- B2.1 — Lister par ordre alphabétique les titres des contenus dont le thème principal
-- comprend le mot « Anime » ou « Fantasy ».

-- Compléter ici


-- ------------------------------------------------------------------------------------------------
-- B2.2 — Lister les titres et les thèmes des contenus empruntés par Dupont entre
-- janvier et mars 2022.

-- Compléter ici


-- ------------------------------------------------------------------------------------------------
-- B2.3 — Donner, pour chaque abonné, son nombre de contenus empruntés et le nombre
-- qu'il peut encore emprunter compte tenu de son abonnement.

-- Compléter ici


-- ------------------------------------------------------------------------------------------------
-- B2.4 — Lister sans doublon les acteurs ayant joué dans un film réalisé par
-- David Fincher, avec le nombre de films tournés avec ce réalisateur pour chacun.

-- Compléter ici


-- ------------------------------------------------------------------------------------------------
-- B2.5 — Trouver le ou les réalisateurs ayant réalisé le plus de contenus.

-- Compléter ici

-- ------------------------------------------------------------------------------------------------
-- B3 — Compléter avec d'autres requêtes utilisant les concepts relationnels-objets.
-- ------------------------------------------------------------------------------------------------
