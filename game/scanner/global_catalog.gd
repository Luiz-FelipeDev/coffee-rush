extends Node

# Sinal que vai gritar para o jogo inteiro quando uma descoberta acontecer.
# O seu livro vai "escutar" esse sinal para atualizar a página na hora!
signal criatura_catalogada(id_criatura: String)

# O nosso banco de dados principal. 
# Coloque aqui o ID (nome) de todas as criaturas do jogo.
var descobertas: Dictionary = {
	"seed_sprout": false,
	"froggit": false, # Exemplo
	"mecha sappo": false     # Exemplo
}

# Função que a luneta vai chamar quando terminar os 2 segundos
func registrar_descoberta(id_criatura: String) -> void:
	# Confere se a criatura existe no nosso dicionário e se ainda não foi descoberta
	if descobertas.has(id_criatura):
		if not descobertas[id_criatura]:
			descobertas[id_criatura] = true
			criatura_catalogada.emit(id_criatura)
			print("✅ Nova entrada no Atlas: ", id_criatura)
		else:
			print("ℹ️ Essa criatura já estava no catálogo!")
	else:
		print("🚨 ERRO: Tentou catalogar um ID que não existe no GlobalCatalog: ", id_criatura)

# Função para o seu Atlas checar se deve mostrar a silhueta ou a foto
func foi_descoberto(id_criatura: String) -> bool:
	if descobertas.has(id_criatura):
		return descobertas[id_criatura]
	return false
